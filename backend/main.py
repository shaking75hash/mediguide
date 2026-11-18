from fastapi.middleware.cors import CORSMiddleware
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from fastapi import Depends, Request
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel, Field
from .database import get_db_connection
from .osm_care_search import (
    CareSearchError,
    search_nearby_doctors,
    search_nearby_hospitals,
    specialty_for_concern,
)
from typing import Optional
import bcrypt
import jwt
import datetime
import os
import hashlib
import secrets
import time
import pyotp
import psycopg2
import threading

from .security import (
    GENERIC_LOGIN,
    GENERIC_DOCTOR_LOGIN,
    create_token,
    decode_token,
    decrypt_totp,
    encrypt_totp,
    new_doctor_id,
    new_totp_secret,
    require_production_secrets,
    verify_totp,
)
from .migrate import migrate
from .specialties import normalize_specialty

app = FastAPI()

# ✅ Allow Flutter Web (Chrome) to talk to this backend
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)
SECRET_KEY = os.getenv("JWT_SECRET") or os.getenv("SECRET_KEY")
require_production_secrets(os.getenv("APP_MODE", "development"))
if os.getenv("RUN_MIGRATIONS_ON_START", "true").lower() == "true":
    migrate()


class DoctorCreate(BaseModel):
    name: str
    specialty: str
    location: str
    fee: int

class UserCreate(BaseModel):
    name: str = Field(min_length=1, max_length=100)
    email: str = Field(max_length=255)
    password: str = Field(min_length=8, max_length=128)

class UserLogin(BaseModel):
    email: str
    password: str

class UserProfileUpdate(BaseModel):
    name: str
    blood_group: Optional[str] = None
    height_cm: Optional[float] = None
    weight_kg: Optional[float] = None
    medical_history: Optional[str] = None

class HealthRecordCreate(BaseModel):
    blood_pressure: Optional[str] = None
    blood_sugar: Optional[float] = None
    weight: Optional[float] = None
    notes: Optional[str] = None

class AppointmentCareNoteUpdate(BaseModel):
    doctor_advice: Optional[str] = Field(default=None, max_length=5000)
    revisit_date: Optional[str] = None
    revisit_notes: Optional[str] = Field(default=None, max_length=1000)


class AdminLogin(BaseModel):
    email: str
    password: str
    code: Optional[str] = None


class AdminInviteCreate(BaseModel):
    email: str


class AdminInviteAccept(BaseModel):
    token: str
    password: str


class DoctorRequestCode(BaseModel):
    email: str


class DoctorRequestCreate(BaseModel):
    full_name: str = Field(max_length=100)
    specialty: str
    qualification: str = Field(max_length=500)
    email: str
    code: str


class DoctorRequestDecision(BaseModel):
    pass


class AdminDoctorCreate(BaseModel):
    name: str = Field(max_length=100)
    specialty: str
    location: str = Field(max_length=100)
    fee: float = Field(ge=0)


class DoctorLogin(BaseModel):
    email: str
    identifier: str


class Reschedule(BaseModel):
    date: str
    time: str


class ScheduleRange(BaseModel):
    day_of_week: int = Field(ge=1, le=7)
    start_time: str
    end_time: str
    session_length_minutes: int = Field(default=30, ge=5, le=60)


class ScheduleReplace(BaseModel):
    ranges: list[ScheduleRange]


class ScheduleResolution(BaseModel):
    appointment_id: int
    action: str
    date: Optional[str] = None
    time: Optional[str] = None


class ScheduleReplaceWithResolutions(BaseModel):
    ranges: list[ScheduleRange]
    resolutions: list[ScheduleResolution] = Field(default_factory=list)


class DayOffCreate(BaseModel):
    date: str
    reason: Optional[str] = Field(default=None, max_length=500)


class DayOffResolution(BaseModel):
    appointment_id: int
    action: str
    date: Optional[str] = None
    time: Optional[str] = None


class DayOffCreateWithResolutions(BaseModel):
    date: str
    reason: Optional[str] = Field(default=None, max_length=500)
    resolutions: list[DayOffResolution] = Field(default_factory=list)
    cancel_all: bool = False

def create_access_token(user_id: int):
    conn = get_db_connection()
    cur = conn.cursor()
    cur.execute("SELECT role, token_version FROM users WHERE id = %s;", (user_id,))
    row = cur.fetchone()
    cur.close()
    conn.close()
    if row is None:
        return None
    return create_token(user_id, row[0], row[1], 30)
# This tells FastAPI: "The key to get a token is found at the /login endpoint"
security = HTTPBearer()

def get_authenticated_user(credentials: HTTPAuthorizationCredentials = Depends(security)):
    credentials_exception = HTTPException(
        status_code=401,
        detail="Could not validate credentials",
        headers={"WWW-Authenticate": "Bearer"},
    )
    token = credentials.credentials
    try:
        payload = decode_token(token)
        user_id = payload.get("user_id")
        role = payload.get("role")
        token_version = payload.get("token_version")
        if user_id is None or role is None or token_version is None:
            raise credentials_exception
    except jwt.ExpiredSignatureError:
        raise HTTPException(status_code=401, detail="Token has expired")
    except jwt.InvalidTokenError:
        raise credentials_exception

    conn = get_db_connection()
    cur = conn.cursor()
    cur.execute(
        "SELECT id, role, token_version, disabled, doctor_id FROM users WHERE id = %s;",
        (user_id,),
    )
    row = cur.fetchone()
    cur.close()
    conn.close()
    if row is None or row[2] != token_version or row[1] != role or row[3]:
        raise credentials_exception
    return {"id": row[0], "role": row[1], "token_version": row[2], "doctor_id": row[4]}


def get_current_user(auth=Depends(get_authenticated_user)):
    if auth["role"] != "patient":
        raise HTTPException(status_code=403, detail="Forbidden")
    return auth["id"]


def require_role(*allowed_roles: str):
    def dependency(auth=Depends(get_authenticated_user)):
        if auth["role"] not in allowed_roles:
            raise HTTPException(status_code=403, detail="Forbidden")
        if auth["role"] == "doctor":
            conn = get_db_connection()
            cur = conn.cursor()
            cur.execute(
                "SELECT deleted_at FROM doctors WHERE id = %s;",
                (auth["doctor_id"],),
            )
            row = cur.fetchone()
            cur.close()
            conn.close()
            if row is None or row[0] is not None:
                raise HTTPException(status_code=401, detail="Could not validate credentials")
        return auth
    return dependency

@app.get("/me")
def get_me(current_user_id: int = Depends(get_current_user)):
    conn = get_db_connection()
    cur = conn.cursor()
    cur.execute(
        """SELECT id, name, email, blood_group, height_cm, weight_kg, medical_history
           FROM users WHERE id = %s;""",
        (current_user_id,),
    )
    row = cur.fetchone()
    cur.close()
    conn.close()

    if row is None:
        raise HTTPException(status_code=404, detail="User not found")

    return {
        "id": row[0],
        "name": row[1],
        "email": row[2],
        "blood_group": row[3],
        "height_cm": row[4],
        "weight_kg": row[5],
        "medical_history": row[6],
        "message": f"Welcome back, {row[1]}! Your token is valid."
    }

@app.put("/me")
def update_me(
    profile: UserProfileUpdate,
    current_user_id: int = Depends(get_current_user),
):
    name = profile.name.strip()
    if not name:
        raise HTTPException(status_code=400, detail="Name cannot be empty")
    if profile.height_cm is not None and not 30 <= profile.height_cm <= 300:
        raise HTTPException(status_code=400, detail="Height must be between 30 and 300 cm")
    if profile.weight_kg is not None and not 1 <= profile.weight_kg <= 500:
        raise HTTPException(status_code=400, detail="Weight must be between 1 and 500 kg")
    blood_group = profile.blood_group.strip().upper() if profile.blood_group else None
    valid_blood_groups = {"A+", "A-", "B+", "B-", "AB+", "AB-", "O+", "O-"}
    if blood_group is not None and blood_group not in valid_blood_groups:
        raise HTTPException(status_code=400, detail="Select a valid blood group")

    conn = get_db_connection()
    cur = conn.cursor()
    cur.execute(
        """UPDATE users
           SET name = %s, blood_group = %s, height_cm = %s,
               weight_kg = %s, medical_history = %s
           WHERE id = %s
           RETURNING id, name, email, blood_group, height_cm, weight_kg, medical_history;""",
        (
            name,
            blood_group or None,
            profile.height_cm,
            profile.weight_kg,
            profile.medical_history.strip() if profile.medical_history else None,
            current_user_id,
        ),
    )
    row = cur.fetchone()
    conn.commit()
    cur.close()
    conn.close()
    if row is None:
        raise HTTPException(status_code=404, detail="User not found")
    return {
        "id": row[0],
        "name": row[1],
        "email": row[2],
        "blood_group": row[3],
        "height_cm": row[4],
        "weight_kg": row[5],
        "medical_history": row[6],
    }

@app.get("/")
def home():
    return {"message": "MediGuide Backend is secure and organized!"}

@app.get("/doctors")
def get_doctors():
    conn = get_db_connection()
    cur = conn.cursor()
    cur.execute(
        "SELECT id, name, specialty, location, consultation_fee, is_verified "
        "FROM doctors WHERE deleted_at IS NULL ORDER BY consultation_fee ASC, id ASC;"
    )
    rows = cur.fetchall()
    cur.close()
    conn.close()

    doctors = []
    for row in rows:
        doctors.append({
            "id": row[0], "name": row[1], "specialty": row[2],
            "location": row[3], "consultation_fee": row[4], "is_verified": row[5]
        })
    return doctors

@app.get("/doctors/search")
def search_doctors(query: str = "", location: str = ""):
    conn = get_db_connection()
    cur = conn.cursor()

    search_term = f"%{query.strip()}%"
    location_term = f"%{location.strip()}%"
    cur.execute(
        "SELECT id, name, specialty, location, consultation_fee, is_verified "
        "FROM doctors "
        "WHERE deleted_at IS NULL "
        "AND (%s = '' OR name ILIKE %s OR specialty ILIKE %s "
        "OR location ILIKE %s) "
        "AND (%s = '' OR location ILIKE %s) "
        "ORDER BY consultation_fee ASC, id ASC;",
        (
            query.strip(),
            search_term,
            search_term,
            search_term,
            location.strip(),
            location_term,
        ),
    )
    rows = cur.fetchall()
    cur.close()
    conn.close()

    doctors = []
    for row in rows:
        doctors.append({
            "id": row[0], "name": row[1], "specialty": row[2],
            "location": row[3], "consultation_fee": row[4], "is_verified": row[5]
        })
    return doctors

@app.get("/hospitals/search")
def search_hospitals(location: str = "", query: str = ""):
    conn = get_db_connection()
    cur = conn.cursor()
    query_term = f"%{query.strip()}%"
    cur.execute(
        "SELECT id, name, category, location, is_sample, "
        "latitude, longitude, source_url "
        "FROM diagnostic_facilities "
        "WHERE category ILIKE %s AND location ILIKE %s "
        "AND (%s = '' OR name ILIKE %s OR category ILIKE %s) "
        "ORDER BY name ASC, id ASC;",
        (
            "%hospital%",
            f"%{location.strip()}%",
            query.strip(),
            query_term,
            query_term,
        ),
    )
    rows = cur.fetchall()
    cur.close()
    conn.close()
    return [
        {
            "id": row[0],
            "name": row[1],
            "category": row[2],
            "location": row[3],
            "is_sample": row[4],
            "latitude": row[5],
            "longitude": row[6],
            "source_url": row[7],
        }
        for row in rows
    ]


@app.get("/care/doctors/search")
def search_nearby_doctors_endpoint(query: str, location: str = "Rajshahi"):
    location = location.strip() or "Rajshahi"
    osm_error = None
    try:
        map_results = search_nearby_doctors(query, location)
        if map_results:
            return map_results
    except CareSearchError as error:
        if error.status_code != 503:
            raise HTTPException(
                status_code=error.status_code, detail=str(error)
            ) from error
        osm_error = error

    directory_results = _search_directory_doctors(query, location)
    if directory_results:
        return directory_results
    if osm_error is not None:
        raise HTTPException(
            status_code=osm_error.status_code, detail=str(osm_error)
        ) from osm_error
    return []


@app.get("/care/hospitals/search")
def search_nearby_hospitals_endpoint(location: str):
    osm_error = None
    try:
        map_results = search_nearby_hospitals(location)
        if map_results:
            return map_results
    except CareSearchError as error:
        if error.status_code != 503:
            raise HTTPException(
                status_code=error.status_code, detail=str(error)
            ) from error
        osm_error = error

    directory_results = _search_directory_hospitals(location)
    if directory_results:
        return directory_results
    if osm_error is not None:
        raise HTTPException(
            status_code=osm_error.status_code, detail=str(osm_error)
        ) from osm_error
    return []


def _location_search_terms(location: str) -> list[str]:
    terms = [location.strip()]
    normalized_location = location.casefold()
    if "kadirganj" in normalized_location:
        terms.append("Rajshahi")
    return terms


def _search_directory_doctors(query: str, location: str) -> list[dict]:
    _, specialty_terms = specialty_for_concern(query)
    search_terms = list(dict.fromkeys([query.strip(), *specialty_terms]))
    search_terms = [term for term in search_terms if term]
    location_terms = _location_search_terms(location)
    if not search_terms or not location_terms:
        return []

    query_conditions = " OR ".join(
        "(name ILIKE %s OR specialty ILIKE %s)" for _ in search_terms
    )
    location_conditions = " OR ".join(
        "location ILIKE %s" for _ in location_terms
    )
    query_parameters = [
        pattern
        for term in search_terms
        for pattern in (f"%{term}%", f"%{term}%")
    ]
    location_parameters = [f"%{term}%" for term in location_terms]

    conn = get_db_connection()
    try:
        cur = conn.cursor()
        try:
            cur.execute(
                "SELECT id, name, specialty, location, consultation_fee, is_verified "
                "FROM doctors "
                f"WHERE deleted_at IS NULL AND ({location_conditions}) AND ({query_conditions}) "
                "ORDER BY consultation_fee ASC, id ASC;",
                (*location_parameters, *query_parameters),
            )
            rows = cur.fetchall()
        finally:
            cur.close()
    finally:
        conn.close()

    results = []
    for row in rows:
        results.append(
            {
                "id": row[0],
                "name": row[1],
                "specialty": row[2],
                "location": row[3],
                "consultation_fee": row[4],
                "is_verified": row[5],
                "specialty_match": any(
                    term.casefold() in str(row[2]).casefold()
                    for term in specialty_terms
                ),
                "source": "local_directory",
            }
        )
    return results


def _search_directory_hospitals(location: str) -> list[dict]:
    location_terms = _location_search_terms(location)
    if not location_terms:
        return []
    location_conditions = " OR ".join(
        "location ILIKE %s" for _ in location_terms
    )
    parameters = ["%hospital%", *(f"%{term}%" for term in location_terms)]

    conn = get_db_connection()
    try:
        cur = conn.cursor()
        try:
            cur.execute(
                "SELECT id, name, category, location, is_sample, "
                "latitude, longitude, source_url "
                "FROM diagnostic_facilities "
                f"WHERE category ILIKE %s AND ({location_conditions}) "
                "ORDER BY name ASC, id ASC;",
                parameters,
            )
            rows = cur.fetchall()
        finally:
            cur.close()
    finally:
        conn.close()

    return [
        {
            "id": row[0],
            "name": row[1],
            "category": row[2],
            "location": row[3],
            "is_sample": row[4],
            "latitude": row[5],
            "longitude": row[6],
            "source_url": row[7],
            "source": "local_directory",
        }
        for row in rows
    ]



@app.get("/medical-services")
def get_medical_services():
    conn = get_db_connection()
    cur = conn.cursor()
    cur.execute(
        "SELECT id, name, category, description "
        "FROM medical_services ORDER BY category, name;"
    )
    rows = cur.fetchall()
    cur.close()
    conn.close()
    return [
        {
            "id": row[0],
            "name": row[1],
            "category": row[2],
            "description": row[3],
        }
        for row in rows
    ]

@app.get("/price-comparison")
def get_price_comparison(service_id: int):
    conn = get_db_connection()
    cur = conn.cursor()
    cur.execute(
        """SELECT facility.id, facility.name, facility.category,
                  facility.location, facility.is_sample, offer.price
           FROM facility_service_prices AS offer
           JOIN diagnostic_facilities AS facility
             ON facility.id = offer.facility_id
           WHERE offer.service_id = %s
           ORDER BY offer.price ASC, facility.name ASC;""",
        (service_id,),
    )
    rows = cur.fetchall()
    cur.close()
    conn.close()

    providers = [
        {
            "facility_id": row[0],
            "name": row[1],
            "category": row[2],
            "location": row[3],
            "is_sample": row[4],
            "price": float(row[5]),
        }
        for row in rows
    ]
    providers.sort(key=lambda provider: (provider["price"], provider["name"]))

    return {
        "service_id": service_id,
        "providers": providers,
    }

@app.get("/doctors/{doctor_id}")
def get_single_doctor(doctor_id: int):
    conn = get_db_connection()
    cur = conn.cursor()
    cur.execute(
        "SELECT id, name, specialty, location, consultation_fee, is_verified "
        "FROM doctors WHERE id = %s AND deleted_at IS NULL;",
        (doctor_id,),
    )
    row = cur.fetchone()
    cur.close()
    conn.close()

    if row is None:
        raise HTTPException(status_code=404, detail="Doctor not found")

    return {
        "id": row[0], "name": row[1], "specialty": row[2],
        "location": row[3], "consultation_fee": row[4], "is_verified": row[5]
    }

@app.get("/doctors/{doctor_id}/trust")
def get_doctor_trust(doctor_id: int):
    conn = get_db_connection()
    cur = conn.cursor()
    cur.execute("SELECT id FROM doctors WHERE id = %s AND deleted_at IS NULL;", (doctor_id,))
    if cur.fetchone() is None:
        cur.close()
        conn.close()
        raise HTTPException(status_code=404, detail="Doctor not found")

    cur.execute("""
        SELECT overall_score, review_score, accreditation_score,
               infrastructure_score, outcome_score, total_reviews, verified_reviews
        FROM doctor_trust_profiles WHERE doctor_id = %s;
    """, (doctor_id,))
    profile = cur.fetchone()

    cur.execute("""
        SELECT body, level, valid_until FROM accreditations
        WHERE doctor_id = %s AND is_active = TRUE;
    """, (doctor_id,))
    accreditations = [
        {"body": r[0], "level": r[1], "valid_until": str(r[2])}
        for r in cur.fetchall()
    ]

    cur.execute("""
        SELECT u.name, pr.rating, pr.comment, pr.created_at
        FROM patient_reviews pr
        LEFT JOIN users u ON pr.patient_id = u.id
        WHERE pr.doctor_id = %s AND pr.is_verified = TRUE
        ORDER BY pr.created_at DESC LIMIT 5;
    """, (doctor_id,))
    reviews = [
        {
            "patient": r[0] or "Anonymous",
            "rating": r[1],
            "comment": r[2],
            "date": str(r[3])[:10],
        }
        for r in cur.fetchall()
    ]

    cur.close()
    conn.close()

    if not profile:
        raise HTTPException(status_code=404, detail="Trust profile not found")

    return {
        "overall_score": float(profile[0]),
        "breakdown": {
            "reviews": float(profile[1]),
            "accreditation": float(profile[2]),
            "infrastructure": float(profile[3]),
            "outcomes": float(profile[4]),
        },
        "total_reviews": profile[5],
        "verified_reviews": profile[6],
        "accreditations": accreditations,
        "recent_reviews": reviews,
    }

@app.get("/doctors/{doctor_id}/insights")
def get_doctor_insights(doctor_id: int):
    conn = get_db_connection()
    cur = conn.cursor()

    cur.execute("""
        SELECT d.consultation_fee, d.specialty, tp.overall_score, tp.verified_reviews
        FROM doctors d
        LEFT JOIN doctor_trust_profiles tp ON d.id = tp.doctor_id
        WHERE d.id = %s AND d.deleted_at IS NULL;
    """, (doctor_id,))
    doc = cur.fetchone()
    if not doc:
        cur.close(); conn.close()
        raise HTTPException(status_code=404, detail="Doctor not found")

    consultation_fee = float(doc[0] or 0)
    specialty = doc[1]
    trust_score = float(doc[2] or 0)
    verified_reviews = doc[3] or 0

    cur.execute("""
        SELECT AVG(pp.price) FROM provider_prices pp
        JOIN medical_services ms ON pp.service_id = ms.id
        WHERE pp.doctor_id = %s AND ms.category = 'Diagnostics';
    """, (doctor_id,))
    avg_diagnostics = cur.fetchone()[0] or 0

    estimated_total = consultation_fee + float(avg_diagnostics)

    cur.execute("""
        SELECT COUNT(*) FROM appointments
        WHERE doctor_id = %s
        AND appointment_date BETWEEN CURRENT_DATE AND CURRENT_DATE + INTERVAL '7 days'
        AND status IN ('scheduled', 'rescheduled');
    """, (doctor_id,))
    upcoming_count = cur.fetchone()[0]

    if upcoming_count <= 5:
        predicted_wait = "5-10 min"
        wait_level = "low"
    elif upcoming_count <= 15:
        predicted_wait = "15-30 min"
        wait_level = "moderate"
    else:
        predicted_wait = "30-60 min"
        wait_level = "high"

    cur.execute("""
        SELECT AVG(tp2.overall_score), MIN(tp2.overall_score), MAX(tp2.overall_score)
        FROM doctor_trust_profiles tp2
        JOIN doctors d2 ON tp2.doctor_id = d2.id
        WHERE d2.specialty = %s;
    """, (specialty,))
    peer_stats = cur.fetchone()
    avg_peer_score = float(peer_stats[0] or 0)

    if trust_score >= avg_peer_score + 0.3:
        quality_vs_peers = "Above Average"
    elif trust_score >= avg_peer_score - 0.3:
        quality_vs_peers = "Average"
    else:
        quality_vs_peers = "Below Average"

    cur.close()
    conn.close()

    return {
        "estimated_cost": {
            "consultation": consultation_fee,
            "avg_diagnostics": round(float(avg_diagnostics), 2),
            "total_estimate": round(estimated_total, 2),
        },
        "predicted_wait": {
            "time": predicted_wait,
            "level": wait_level,
            "upcoming_appointments": upcoming_count,
        },
        "quality_comparison": {
            "doctor_score": trust_score,
            "peer_average": round(avg_peer_score, 2),
            "verdict": quality_vs_peers,
            "verified_reviews": verified_reviews,
        },
    }


# --- REGISTER A NEW USER ---
@app.post("/register", status_code=201)
def register_user(user: UserCreate):
    conn = get_db_connection()
    cur = conn.cursor()

    cur.execute("SELECT id FROM users WHERE email = %s;", (user.email,))
    if cur.fetchone() is not None:
        cur.close()
        conn.close()
        raise HTTPException(status_code=400, detail="Email already registered")

    # ✅ MODERN BCRYPT:
    # 1. Convert string password to bytes
    password_bytes = user.password.encode('utf-8')

    # 2. Generate a random "salt" and hash the bytes
    salt = bcrypt.gensalt()
    hashed_password_bytes = bcrypt.hashpw(password_bytes, salt)

    # 3. Convert the hashed bytes back to a string so PostgreSQL can save it
    hashed_password_str = hashed_password_bytes.decode('utf-8')

    # Save to database
    cur.execute(
        """
        INSERT INTO users (name, email, password_hash, role, token_version)
        VALUES (%s, %s, %s, 'patient', 1)
        RETURNING id, name, email, created_at;
        """,
        (user.name, user.email, hashed_password_str) # <-- Use the string version here
    )

    new_user = cur.fetchone()
    conn.commit()
    cur.close()
    conn.close()

    return {
        "id": new_user[0], "name": new_user[1],
        "email": new_user[2], "created_at": new_user[3],
        "message": "User registered successfully"
    }
# --- LOGIN USER ---
@app.post("/login")
def login_user(credentials: UserLogin, request: Request):
    email = credentials.email.strip().lower()
    ip = request.client.host if request.client else "unknown"
    identity = f"{email}|{ip}"
    if is_rate_limited("patient_login", identity):
        raise HTTPException(status_code=429, detail="Too many attempts")
    conn = get_db_connection()
    cur = conn.cursor()

    cur.execute(
        "SELECT id, name, password_hash, role, token_version, disabled "
        "FROM users WHERE email = %s;",
        (email,),
    )
    user_row = cur.fetchone()
    cur.close()
    conn.close()

    if user_row is None or user_row[5]:
        raise HTTPException(status_code=401, detail="Invalid email or password")
    if user_row[3] != "patient":
        raise HTTPException(status_code=403, detail="Forbidden")

    # ✅ MODERN BCRYPT:
    # 1. Convert the typed password to bytes
    typed_password_bytes = credentials.password.encode('utf-8')

    # 2. Get the hash from the database (it's a string) and convert it to bytes
    db_hash_bytes = user_row[2].encode('utf-8')

    # 3. Compare them!
    is_password_correct = bcrypt.checkpw(typed_password_bytes, db_hash_bytes)

    if not is_password_correct:
        raise HTTPException(status_code=401, detail="Invalid email or password")

    # ✅ NEW: Generate the JWT Keycard!
    access_token = create_access_token(user_row[0])
    clear_rate_limit("patient_login", identity)

    return {
        "access_token": access_token,
        "token_type": "bearer",
        "role": "patient",
        "message": "Login successful"
    }
# ---------- APPOINTMENT SYSTEM ----------

# Get available 30-min slots for a doctor on a specific date (YYYY-MM-DD)
@app.get("/doctors/{doctor_id}/slots")
def get_slots(doctor_id: int, date: str):
    try:
        target_date = datetime.date.fromisoformat(date)
    except ValueError:
        raise HTTPException(status_code=400, detail="Date must be YYYY-MM-DD")

    weekday = target_date.isoweekday()  # 1=Mon .. 7=Sun
    conn = get_db_connection()
    cur = conn.cursor()
    cur.execute(
        "SELECT id FROM doctors WHERE id = %s AND deleted_at IS NULL;",
        (doctor_id,),
    )
    if cur.fetchone() is None:
        cur.close()
        conn.close()
        raise HTTPException(status_code=404, detail="Doctor not found")

    # Find the doctor's working hours for that weekday
    cur.execute(
        "SELECT start_time, end_time, session_length_minutes "
        "FROM doctor_schedules WHERE doctor_id = %s AND day_of_week = %s;",
        (doctor_id, weekday),
    )
    schedules = cur.fetchall()
    cur.execute(
        "SELECT id FROM doctor_days_off WHERE doctor_id = %s AND off_date = %s;",
        (doctor_id, target_date),
    )
    if cur.fetchone() or not schedules:
        cur.close(); conn.close()
        return {"date": date, "slots": []}  # doctor off that day
    all_slots = []
    for start_t, end_t, session_minutes in schedules:
        current = datetime.datetime.combine(target_date, start_t)
        end_dt = datetime.datetime.combine(target_date, end_t)
        while current + datetime.timedelta(minutes=session_minutes) <= end_dt:
            all_slots.append(current.strftime("%H:%M"))
            current += datetime.timedelta(minutes=session_minutes)

    # Remove already-booked slots
    cur.execute(
        "SELECT appointment_time::text FROM appointments "
        "WHERE doctor_id = %s AND appointment_date = %s "
        "AND status IN ('scheduled', 'rescheduled');",
        (doctor_id, target_date),
    )
    booked = {row[0][:5] for row in cur.fetchall()}
    cur.close(); conn.close()

    available = [s for s in all_slots if s not in booked]
    return {"date": date, "slots": available}


# Book an appointment (PROTECTED — needs login)
@app.post("/appointments", status_code=201)
def book_appointment(
    doctor_id: int,
    date: str,
    time: str,
    patient_id: int = Depends(get_current_user),
):
    try:
        target_date = datetime.date.fromisoformat(date)
        target_time = datetime.time.fromisoformat(time)
    except ValueError:
        raise HTTPException(status_code=400, detail="Invalid date/time format")

    conn = get_db_connection()
    cur = conn.cursor()
    cur.execute(
        "SELECT id FROM doctors WHERE id = %s AND deleted_at IS NULL;",
        (doctor_id,),
    )
    if cur.fetchone() is None:
        cur.close()
        conn.close()
        raise HTTPException(status_code=404, detail="Doctor not found")

    cur.execute(
        "SELECT id FROM doctor_days_off WHERE doctor_id = %s AND off_date = %s;",
        (doctor_id, target_date),
    )
    if cur.fetchone():
        cur.close()
        conn.close()
        raise HTTPException(status_code=409, detail="The doctor is unavailable on this date")

    try:
        validate_slot(cur, doctor_id, 0, target_date, target_time)
    except HTTPException:
        cur.close()
        conn.close()
        raise

    # Prevent double-booking
    cur.execute(
        "SELECT id FROM appointments WHERE doctor_id = %s AND appointment_date = %s "
        "AND appointment_time = %s AND status IN ('scheduled', 'rescheduled');",
        (doctor_id, target_date, target_time),
    )
    if cur.fetchone():
        cur.close(); conn.close()
        raise HTTPException(status_code=409, detail="This slot is already booked")

    cur.execute(
        """INSERT INTO appointments (patient_id, doctor_id, appointment_date, appointment_time)
           VALUES (%s, %s, %s, %s) RETURNING id;""",
        (patient_id, doctor_id, target_date, target_time),
    )
    new_id = cur.fetchone()[0]
    conn.commit()
    cur.close(); conn.close()

    return {"id": new_id, "message": "Appointment booked successfully!"}


# My appointments (PROTECTED)
@app.get("/appointments/mine")
def my_appointments(patient_id: int = Depends(get_current_user)):
    conn = get_db_connection()
    cur = conn.cursor()
    cur.execute(
        """SELECT a.id, d.name, d.specialty, a.appointment_date, a.appointment_time, a.status
           FROM appointments a JOIN doctors d ON a.doctor_id = d.id
           WHERE a.patient_id = %s ORDER BY a.appointment_date, a.appointment_time;""",
        (patient_id,),
    )
    rows = cur.fetchall()
    cur.close(); conn.close()

    return [
        {
            "id": r[0], "doctor_name": r[1], "specialty": r[2],
            "date": str(r[3]), "time": str(r[4])[:5], "status": r[5],
        }
        for r in rows
    ]


@app.delete("/appointments/{appointment_id}")
def cancel_appointment(
    appointment_id: int,
    current_user_id: int = Depends(get_current_user),
):
    conn = get_db_connection()
    cur = conn.cursor()

    cur.execute(
        "SELECT id FROM appointments WHERE id = %s AND patient_id = %s;",
        (appointment_id, current_user_id),
    )
    if cur.fetchone() is None:
        cur.close()
        conn.close()
        raise HTTPException(
            status_code=404,
            detail="Appointment not found or unauthorized",
        )

    cur.execute("DELETE FROM appointments WHERE id = %s;", (appointment_id,))
    conn.commit()
    cur.close()
    conn.close()

    return {"message": "Appointment cancelled successfully"}


@app.get("/appointments/care-notes")
def get_appointment_care_notes(
    current_user_id: int = Depends(get_current_user),
):
    conn = get_db_connection()
    cur = conn.cursor()
    cur.execute(
        """SELECT a.id, d.name, d.specialty, a.appointment_date,
                  a.appointment_time, a.doctor_advice, a.revisit_date,
                  a.revisit_notes
           FROM appointments a
           JOIN doctors d ON d.id = a.doctor_id
           WHERE a.patient_id = %s AND a.appointment_date <= CURRENT_DATE
           ORDER BY a.appointment_date DESC, a.appointment_time DESC;""",
        (current_user_id,),
    )
    rows = cur.fetchall()
    cur.close()
    conn.close()

    return [
        {
            "appointment_id": row[0],
            "doctor_name": row[1],
            "specialty": row[2],
            "appointment_date": str(row[3]),
            "appointment_time": str(row[4])[:5],
            "doctor_advice": row[5],
            "revisit_date": str(row[6]) if row[6] else None,
            "revisit_notes": row[7],
        }
        for row in rows
    ]


@app.put("/appointments/{appointment_id}/care-notes")
def update_appointment_care_notes(
    appointment_id: int,
    care_note: AppointmentCareNoteUpdate,
    current_user_id: int = Depends(get_current_user),
):
    revisit_notes = care_note.revisit_notes.strip() if care_note.revisit_notes else None

    revisit_date = None
    if care_note.revisit_date:
        try:
            revisit_date = datetime.date.fromisoformat(care_note.revisit_date)
        except ValueError:
            raise HTTPException(
                status_code=400,
                detail="Revisit date must be in YYYY-MM-DD format",
            )

    conn = get_db_connection()
    cur = conn.cursor()
    cur.execute(
        """SELECT appointment_date FROM appointments
           WHERE id = %s AND patient_id = %s;""",
        (appointment_id, current_user_id),
    )
    appointment = cur.fetchone()
    if appointment is None:
        cur.close()
        conn.close()
        raise HTTPException(status_code=404, detail="Appointment not found")
    if appointment[0] > datetime.date.today():
        cur.close()
        conn.close()
        raise HTTPException(
            status_code=400,
            detail="Care notes can be added after the appointment date",
        )
    if revisit_date is not None and revisit_date < appointment[0]:
        cur.close()
        conn.close()
        raise HTTPException(
            status_code=400,
            detail="Revisit date cannot be before the appointment",
        )

    cur.execute(
        """UPDATE appointments
           SET revisit_date = %s, revisit_notes = %s
           WHERE id = %s AND patient_id = %s;""",
        (revisit_date, revisit_notes or None, appointment_id, current_user_id),
    )
    conn.commit()
    cur.close()
    conn.close()
    return {"message": "Care notes saved"}


@app.post("/health-records", status_code=201)
def add_health_record(
    record: HealthRecordCreate,
    current_user_id: int = Depends(get_current_user),
):
    conn = get_db_connection()
    cur = conn.cursor()
    cur.execute(
        """INSERT INTO patient_records (user_id, blood_pressure, blood_sugar, weight, notes)
           VALUES (%s, %s, %s, %s, %s) RETURNING id;""",
        (
            current_user_id,
            record.blood_pressure,
            record.blood_sugar,
            record.weight,
            record.notes,
        ),
    )
    new_id = cur.fetchone()[0]
    conn.commit()
    cur.close()
    conn.close()
    return {"id": new_id, "message": "Health record saved"}


@app.get("/health-records")
def get_health_records(current_user_id: int = Depends(get_current_user)):
    conn = get_db_connection()
    cur = conn.cursor()
    cur.execute(
        "SELECT id, record_date, blood_pressure, blood_sugar, weight, notes "
        "FROM patient_records WHERE user_id = %s ORDER BY record_date DESC;",
        (current_user_id,),
    )
    rows = cur.fetchall()
    cur.close()
    conn.close()

    records = []
    for row in rows:
        records.append({
            "id": row[0], "date": str(row[1]), "bp": row[2],
            "sugar": row[3], "weight": row[4], "notes": row[5]
        })
    return records


ADMIN_ACTION_LIMITS = {
    "failures": {},
}
DOCTOR_LOGIN_FAILURES = {}

RATE_LIMITS = {}
RATE_LOCK = threading.Lock()


def is_rate_limited(scope: str, identity: str) -> bool:
    redis_url = os.getenv("REDIS_URL")
    window_seconds = int(os.getenv("RATE_LIMIT_WINDOW_MIN", "15")) * 60
    limit = int(os.getenv("RATE_LIMIT_FAILURES", "5"))
    key = f"{scope}:{identity}"
    if redis_url:
        try:
            import redis
            client = redis.from_url(redis_url)
            count = client.incr(key)
            if count == 1:
                client.expire(key, window_seconds)
            return count > limit
        except Exception:
            pass
    now = time.time()
    with RATE_LOCK:
        timestamps = [value for value in RATE_LIMITS.get(key, []) if now - value < window_seconds]
        timestamps.append(now)
        RATE_LIMITS[key] = timestamps
        return len(timestamps) > limit


def clear_rate_limit(scope: str, identity: str) -> None:
    redis_url = os.getenv("REDIS_URL")
    key = f"{scope}:{identity}"
    if redis_url:
        try:
            import redis
            redis.from_url(redis_url).delete(key)
        except Exception:
            pass
    with RATE_LOCK:
        RATE_LIMITS.pop(key, None)


def audit(cur, administrator_id, action, target_type=None, target_id=None, ip_address=None):
    cur.execute(
        """INSERT INTO admin_audit_log
           (administrator_id, action, target_type, target_id, ip_address)
           VALUES (%s, %s, %s, %s, %s);""",
        (administrator_id, action, target_type, str(target_id) if target_id is not None else None, ip_address),
    )


@app.post("/admin/login")
def admin_login(credentials: AdminLogin, request: Request):
    ip = request.client.host if request.client else "unknown"
    identity = f"{credentials.email.strip().lower()}|{ip}"
    if is_rate_limited("admin_login", identity):
        raise HTTPException(status_code=429, detail="Too many attempts")
    conn = get_db_connection()
    cur = conn.cursor()
    cur.execute(
        "SELECT id, password_hash, role, token_version, totp_secret_encrypted, totp_enabled, disabled "
        "FROM users WHERE email = %s;",
        (credentials.email.strip().lower(),),
    )
    row = cur.fetchone()
    valid_password = False
    valid_totp = False
    if row and not row[6] and row[2] == "admin":
        valid_password = bcrypt.checkpw(credentials.password.encode(), row[1].encode())
        if valid_password and row[4] and row[5]:
            try:
                valid_totp = verify_totp(decrypt_totp(row[4]), credentials.code or "")
            except Exception:
                valid_totp = False
    if not valid_password or not valid_totp:
        audit(cur, row[0] if row else None, "admin_login_failed", "user", row[0] if row else None, request.client.host if request.client else None)
        conn.commit()
        cur.close()
        conn.close()
        raise HTTPException(status_code=401, detail=GENERIC_LOGIN)

    cur.execute("UPDATE users SET last_login_at = CURRENT_TIMESTAMP WHERE id = %s;", (row[0],))
    audit(cur, row[0], "admin_login_success", "user", row[0], request.client.host if request.client else None)
    conn.commit()
    clear_rate_limit("admin_login", identity)
    token = create_token(row[0], "admin", row[3], int(os.getenv("ADMIN_TOKEN_MINUTES", "10")))
    cur.close()
    conn.close()
    return {"access_token": token, "token_type": "bearer", "role": "admin"}


@app.post("/admin/invites", status_code=201)
def create_admin_invite(body: AdminInviteCreate, request: Request, auth=Depends(require_role("admin"))):
    token = secrets.token_urlsafe(32)
    token_hash = hashlib.sha256(token.encode()).hexdigest()
    conn = get_db_connection()
    cur = conn.cursor()
    cur.execute(
        """INSERT INTO admin_invites (token_hash, email, created_by, expires_at)
           VALUES (%s, %s, %s, CURRENT_TIMESTAMP + INTERVAL '24 hours') RETURNING id;""",
        (token_hash, body.email.strip().lower(), auth["id"]),
    )
    invite_id = cur.fetchone()[0]
    audit(cur, auth["id"], "admin_invite_created", "admin_invite", invite_id, request.client.host if request.client else None)
    conn.commit()
    cur.close()
    conn.close()
    return {"invite_id": invite_id, "token": token, "expires_in": "24 hours"}


@app.post("/admin/invites/accept")
def accept_admin_invite(body: AdminInviteAccept, request: Request):
    token_hash = hashlib.sha256(body.token.encode()).hexdigest()
    conn = get_db_connection()
    cur = conn.cursor()
    cur.execute(
        """SELECT id, email, expires_at, used_at FROM admin_invites
           WHERE token_hash = %s;""",
        (token_hash,),
    )
    invite = cur.fetchone()
    now = datetime.datetime.now(datetime.timezone.utc)
    if invite is None or invite[3] is not None or invite[2] <= now:
        cur.close()
        conn.close()
        raise HTTPException(status_code=401, detail="Invite is invalid or expired")

    cur.execute("SELECT id FROM users WHERE email = %s;", (invite[1],))
    if cur.fetchone():
        cur.close()
        conn.close()
        raise HTTPException(status_code=409, detail="Email already registered")

    secret = new_totp_secret()
    encrypted = encrypt_totp(secret)
    password_hash = bcrypt.hashpw(body.password.encode(), bcrypt.gensalt()).decode()
    cur.execute(
        """INSERT INTO users (name, email, password_hash, role, token_version,
                              totp_secret_encrypted, totp_enabled)
           VALUES (%s, %s, %s, 'admin', 1, %s, TRUE)
           RETURNING id;""",
        ("Administrator", invite[1], password_hash, encrypted),
    )
    user_id = cur.fetchone()[0]
    audit(cur, user_id, "admin_invite_accepted", "admin_invite", invite[0], request.client.host if request.client else None)
    cur.execute("DELETE FROM admin_invites WHERE id = %s;", (invite[0],))
    conn.commit()
    otpauth = pyotp.TOTP(secret).provisioning_uri(name=invite[1], issuer_name="MediGuide")
    cur.close()
    conn.close()
    return {"message": "Administrator account created", "totp_secret": secret, "otpauth_uri": otpauth}


@app.post("/admin/doctors", status_code=201)
def admin_create_doctor(body: AdminDoctorCreate, request: Request, auth=Depends(require_role("admin"))):
    specialty = normalize_specialty(body.specialty)
    if specialty is None:
        raise HTTPException(status_code=422, detail="Invalid specialty")
    conn = get_db_connection()
    cur = conn.cursor()
    cur.execute(
        """INSERT INTO doctors (name, specialty, location, consultation_fee, is_verified)
           VALUES (%s, %s, %s, %s, TRUE) RETURNING id;""",
        (body.name.strip(), specialty, body.location.strip(), body.fee),
    )
    doctor_id = cur.fetchone()[0]
    audit(cur, auth["id"], "doctor_created", "doctor", doctor_id, request.client.host if request.client else None)
    conn.commit()
    cur.close()
    conn.close()
    return {"id": doctor_id}


@app.delete("/admin/doctors/{doctor_id}")
def admin_delete_doctor(doctor_id: int, request: Request, auth=Depends(require_role("admin"))):
    conn = get_db_connection()
    cur = conn.cursor()
    cur.execute("SELECT id FROM doctors WHERE id = %s AND deleted_at IS NULL;", (doctor_id,))
    if cur.fetchone() is None:
        cur.close()
        conn.close()
        raise HTTPException(status_code=404, detail="Doctor not found")
    cur.execute(
        """SELECT id, appointment_date, appointment_time FROM appointments
           WHERE doctor_id = %s AND status IN ('scheduled', 'rescheduled')
           AND (appointment_date > CURRENT_DATE OR (appointment_date = CURRENT_DATE AND appointment_time > CURRENT_TIME));""",
        (doctor_id,),
    )
    future = cur.fetchall()
    if future:
        cur.close()
        conn.close()
        raise HTTPException(status_code=409, detail={
            "message": "Doctor has future appointments",
            "appointments": [{"id": r[0], "date": str(r[1]), "time": str(r[2])[:5]} for r in future],
        })
    cur.execute("UPDATE doctors SET deleted_at = CURRENT_TIMESTAMP WHERE id = %s;", (doctor_id,))
    cur.execute(
        "UPDATE users SET disabled = TRUE, token_version = token_version + 1 "
        "WHERE role = 'doctor' AND doctor_id = %s;",
        (doctor_id,),
    )
    cur.execute(
        "UPDATE doctor_credentials SET revoked_at = CURRENT_TIMESTAMP "
        "WHERE revoked_at IS NULL AND request_id IN "
        "(SELECT approved_request_id FROM doctors WHERE id = %s);",
        (doctor_id,),
    )
    audit(cur, auth["id"], "doctor_deleted", "doctor", doctor_id, request.client.host if request.client else None)
    conn.commit()
    cur.close()
    conn.close()
    return {"message": "Doctor deleted"}


@app.post("/admin/users/{user_id}/revoke")
def revoke_user(user_id: int, request: Request, auth=Depends(require_role("admin"))):
    conn = get_db_connection()
    cur = conn.cursor()
    cur.execute(
        "UPDATE users SET disabled = TRUE, token_version = token_version + 1 WHERE id = %s;",
        (user_id,),
    )
    audit(cur, auth["id"], "account_revoked", "user", user_id, request.client.host if request.client else None)
    conn.commit()
    cur.close()
    conn.close()
    return {"message": "Account revoked"}
@app.post("/doctor-requests/email-code", status_code=201)
def send_doctor_verification(body: DoctorRequestCode, request: Request):
    email = body.email.strip().lower()
    ip = request.client.host if request.client else "unknown"
    if is_rate_limited("email_code", f"{email}|{ip}"):
        raise HTTPException(status_code=429, detail="Too many attempts")
    code = f"{secrets.randbelow(1000000):06d}"
    code_hash = hashlib.sha256(code.encode()).hexdigest()
    conn = get_db_connection()
    cur = conn.cursor()
    cur.execute(
        """INSERT INTO email_verifications (email, code_hash, expires_at)
           VALUES (%s, %s, CURRENT_TIMESTAMP + INTERVAL '10 minutes');""",
        (email, code_hash),
    )
    cur.execute(
        """INSERT INTO email_outbox (recipient, subject, body)
           VALUES (%s, 'MediGuide verification code', %s);""",
        (email, f"Your MediGuide verification code is {code}. It expires in 10 minutes."),
    )
    conn.commit()
    cur.close()
    conn.close()
    return {"message": "Verification code sent"}


@app.post("/doctor-requests", status_code=201)
def submit_doctor_request(body: DoctorRequestCreate, request: Request):
    specialty = normalize_specialty(body.specialty)
    if specialty is None:
        raise HTTPException(status_code=422, detail="Invalid specialty")
    email = body.email.strip().lower()
    ip = request.client.host if request.client else "unknown"
    if is_rate_limited("doctor_request", f"{email}|{ip}"):
        raise HTTPException(status_code=429, detail="Too many attempts")
    code_hash = hashlib.sha256(body.code.strip().encode()).hexdigest()
    conn = get_db_connection()
    cur = conn.cursor()
    cur.execute(
        """SELECT id, code_hash, expires_at, attempt_count, used_at
           FROM email_verifications WHERE email = %s
           ORDER BY id DESC LIMIT 1 FOR UPDATE;""",
        (email,),
    )
    verification = cur.fetchone()
    if verification is None:
        cur.close()
        conn.close()
        raise HTTPException(status_code=400, detail="Email is not verified")
    if verification[3] >= 5:
        cur.close()
        conn.close()
        raise HTTPException(status_code=429, detail="Too many attempts")
    cur.execute(
        "UPDATE email_verifications SET attempt_count = attempt_count + 1 WHERE id = %s;",
        (verification[0],),
    )
    if (verification[4] is not None or verification[2] <= datetime.datetime.now(datetime.timezone.utc)
            or verification[1] != code_hash):
        conn.commit()
        cur.close()
        conn.close()
        raise HTTPException(status_code=400, detail="Email is not verified")
    cur.execute("UPDATE email_verifications SET used_at = CURRENT_TIMESTAMP WHERE id = %s;", (verification[0],))
    cur.execute(
        """INSERT INTO doctor_requests (full_name, specialty, qualification, email, status)
           VALUES (%s, %s, %s, %s, 'pending') RETURNING id;""",
        (body.full_name.strip(), specialty, body.qualification.strip(), email),
    )
    request_id = cur.fetchone()[0]
    conn.commit()
    cur.close()
    conn.close()
    return {"message": "Your request was received", "request_id": request_id}


@app.get("/admin/doctor-requests")
def list_doctor_requests(status: str = "pending", auth=Depends(require_role("admin"))):
    conn = get_db_connection()
    cur = conn.cursor()
    cur.execute(
        """SELECT id, full_name, specialty, qualification, email, status, created_at
           FROM doctor_requests WHERE status = %s ORDER BY created_at DESC;""",
        (status,),
    )
    rows = cur.fetchall()
    cur.close()
    conn.close()
    return [{"id": r[0], "full_name": r[1], "specialty": r[2], "qualification": r[3],
             "email": r[4], "status": r[5], "created_at": r[6]} for r in rows]


def issue_doctor_credential(cur, request_id: int, email: str):
    identifier = new_doctor_id()
    identifier_hash = bcrypt.hashpw(identifier.encode(), bcrypt.gensalt()).decode()
    days = int(os.getenv("DOCTOR_ID_DAYS", "30"))
    cur.execute(
        """UPDATE doctor_credentials SET revoked_at = CURRENT_TIMESTAMP
           WHERE request_id = %s AND revoked_at IS NULL;""",
        (request_id,),
    )
    cur.execute(
        """INSERT INTO doctor_credentials (request_id, email, identifier_hash, expires_at)
           VALUES (%s, %s, %s, CURRENT_TIMESTAMP + (%s * INTERVAL '1 day')) RETURNING id;""",
        (request_id, email, identifier_hash, days),
    )
    credential_id = cur.fetchone()[0]
    return identifier, credential_id


@app.post("/admin/doctor-requests/{request_id}/approve")
def approve_doctor_request(request_id: int, http_request: Request, auth=Depends(require_role("admin"))):
    conn = get_db_connection()
    cur = conn.cursor()
    cur.execute("SELECT id, full_name, specialty, email, status FROM doctor_requests WHERE id = %s FOR UPDATE;", (request_id,))
    doctor_request = cur.fetchone()
    if doctor_request is None:
        cur.close()
        conn.close()
        raise HTTPException(status_code=404, detail="Doctor request not found")
    if doctor_request[4] != "pending":
        cur.close()
        conn.close()
        raise HTTPException(status_code=409, detail="Doctor request has already been reviewed")

    cur.execute(
        """INSERT INTO doctors (name, specialty, consultation_fee, is_verified, approved_request_id)
           VALUES (%s, %s, 0, TRUE, %s) RETURNING id;""",
        (doctor_request[1], doctor_request[2], request_id),
    )
    doctor_id = cur.fetchone()[0]
    password_hash = bcrypt.hashpw(secrets.token_urlsafe(24).encode(), bcrypt.gensalt()).decode()
    cur.execute(
        """INSERT INTO users (name, email, password_hash, role, doctor_id, token_version)
           VALUES (%s, %s, %s, 'doctor', %s, 1) RETURNING id;""",
        (doctor_request[1], doctor_request[3], password_hash, doctor_id),
    )
    user_id = cur.fetchone()[0]
    identifier, credential_id = issue_doctor_credential(cur, request_id, doctor_request[3])
    cur.execute(
        "UPDATE doctor_requests SET status = 'approved', reviewer_id = %s, reviewed_at = CURRENT_TIMESTAMP WHERE id = %s;",
        (auth["id"], request_id),
    )
    cur.execute(
        """INSERT INTO email_outbox (recipient, subject, body)
           VALUES (%s, 'MediGuide doctor identifier', %s);""",
        (doctor_request[3], f"Your MediGuide doctor identifier is {identifier}. Keep it private."),
    )
    audit(cur, auth["id"], "doctor_request_approved", "doctor_request", request_id, http_request.client.host if http_request.client else None)
    conn.commit()
    cur.close()
    conn.close()
    return {"message": "Doctor request approved", "doctor_id": doctor_id, "identifier": identifier}


@app.post("/admin/doctor-requests/{request_id}/reject")
def reject_doctor_request(request_id: int, http_request: Request, auth=Depends(require_role("admin"))):
    conn = get_db_connection()
    cur = conn.cursor()
    cur.execute("UPDATE doctor_requests SET status = 'rejected', reviewer_id = %s, reviewed_at = CURRENT_TIMESTAMP WHERE id = %s AND status = 'pending' RETURNING id;", (auth["id"], request_id))
    row = cur.fetchone()
    if row is None:
        cur.close()
        conn.close()
        raise HTTPException(status_code=409, detail="Doctor request could not be rejected")
    audit(cur, auth["id"], "doctor_request_rejected", "doctor_request", request_id, http_request.client.host if http_request.client else None)
    conn.commit()
    cur.close()
    conn.close()
    return {"message": "Request rejected"}


@app.post("/admin/doctors/{request_id}/reissue-id")
def reissue_doctor_id(request_id: int, http_request: Request, auth=Depends(require_role("admin"))):
    conn = get_db_connection()
    cur = conn.cursor()
    cur.execute("SELECT email FROM doctor_requests WHERE id = %s AND status = 'approved';", (request_id,))
    row = cur.fetchone()
    if row is None:
        cur.close()
        conn.close()
        raise HTTPException(status_code=404, detail="Approved doctor request not found")
    identifier, credential_id = issue_doctor_credential(cur, request_id, row[0])
    cur.execute(
        """INSERT INTO email_outbox (recipient, subject, body)
           VALUES (%s, 'MediGuide doctor identifier', %s);""",
        (row[0], f"Your replacement MediGuide doctor identifier is {identifier}. Keep it private."),
    )
    audit(cur, auth["id"], "doctor_identifier_reissued", "doctor_request", request_id, http_request.client.host if http_request.client else None)
    conn.commit()
    cur.close()
    conn.close()
    return {"message": "Identifier reissued", "identifier": identifier}


@app.post("/doctor/login")
def doctor_login(body: DoctorLogin, request: Request):
    email = body.email.strip().lower()
    ip = request.client.host if request.client else "unknown"
    if is_rate_limited("doctor_login", f"{email}|{ip}"):
        raise HTTPException(status_code=429, detail="Too many attempts")
    now = time.time()
    failures = [timestamp for timestamp in DOCTOR_LOGIN_FAILURES.get(email, []) if now - timestamp < int(os.getenv("RATE_LIMIT_WINDOW_MIN", "15")) * 60]
    if len(failures) >= int(os.getenv("RATE_LIMIT_FAILURES", "5")):
        DOCTOR_LOGIN_FAILURES[email] = failures
        raise HTTPException(status_code=429, detail="Too many attempts")

    conn = get_db_connection()
    cur = conn.cursor()
    cur.execute(
        """SELECT c.identifier_hash, c.expires_at, c.revoked_at, c.used_at, c.request_id,
                  u.id, u.role, u.token_version, u.disabled, u.doctor_id
           FROM doctor_credentials c
           JOIN doctor_requests r ON r.id = c.request_id
           JOIN users u ON u.email = r.email
           WHERE c.email = %s ORDER BY c.id DESC LIMIT 1;""",
        (email,),
    )
    row = cur.fetchone()
    valid = False
    if row and not row[8]:
        valid = (
            row[1] > datetime.datetime.now(datetime.timezone.utc)
            and row[2] is None
            and row[6] == "doctor"
            and bcrypt.checkpw(body.identifier.encode(), row[0].encode())
        )
    if not valid:
        failures.append(now)
        DOCTOR_LOGIN_FAILURES[email] = failures
        cur.close()
        conn.close()
        raise HTTPException(status_code=401, detail=GENERIC_DOCTOR_LOGIN)
    cur.execute("UPDATE doctor_credentials SET used_at = CURRENT_TIMESTAMP WHERE request_id = %s AND revoked_at IS NULL;", (row[4],))
    cur.execute("UPDATE users SET last_login_at = CURRENT_TIMESTAMP WHERE id = %s;", (row[5],))
    conn.commit()
    token = create_token(row[5], "doctor", row[7], 30)
    cur.close()
    conn.close()
    DOCTOR_LOGIN_FAILURES.pop(email, None)
    clear_rate_limit("doctor_login", f"{email}|{ip}")
    return {"access_token": token, "token_type": "bearer", "role": "doctor"}


@app.get("/doctor/appointments")
def doctor_appointments(date: str = "", auth=Depends(require_role("doctor"))):
    conn = get_db_connection()
    cur = conn.cursor()
    try:
        target = datetime.date.fromisoformat(date) if date else None
    except ValueError:
        cur.close()
        conn.close()
        raise HTTPException(status_code=422, detail="Date must use YYYY-MM-DD")
    params = (auth["doctor_id"],)
    date_filter = ""
    if target is not None:
        date_filter = " AND a.appointment_date = %s"
        params = (auth["doctor_id"], target)
    cur.execute(
        """SELECT a.id, a.patient_id, u.name, a.appointment_date,
                  a.appointment_time, a.status, a.doctor_advice,
                  a.revisit_date, a.revisit_notes
           FROM appointments a
           JOIN users u ON u.id = a.patient_id
           WHERE a.doctor_id = %s""" + date_filter + """
           ORDER BY a.appointment_date, a.appointment_time;""",
        params,
    )
    rows = cur.fetchall()
    cur.close()
    conn.close()
    return [{
        "id": r[0],
        "patient_id": r[1],
        "patient_name": r[2],
        "date": str(r[3]),
        "time": str(r[4])[:5],
        "status": r[5],
        "doctor_advice": r[6],
        "revisit_date": str(r[7]) if r[7] else None,
        "revisit_notes": r[8],
    } for r in rows]


def validate_slot(cur, doctor_id: int, appointment_id: int, target_date, target_time):
    target_dt = datetime.datetime.combine(target_date, target_time)
    if target_dt <= datetime.datetime.now():
        raise HTTPException(status_code=422, detail="Target slot must be in the future")
    if target_time.minute % 5 or target_time.second:
        raise HTTPException(status_code=422, detail="Times must be multiples of 5 minutes")
    cur.execute(
        "SELECT id FROM doctor_days_off WHERE doctor_id = %s AND off_date = %s;",
        (doctor_id, target_date),
    )
    if cur.fetchone():
        raise HTTPException(status_code=422, detail="The doctor is unavailable on this date")
    cur.execute(
        "SELECT start_time, end_time, session_length_minutes FROM doctor_schedules "
        "WHERE doctor_id = %s AND day_of_week = %s;",
        (doctor_id, target_date.isoweekday()),
    )
    fits = False
    for start, end, session_minutes in cur.fetchall():
        range_start = datetime.datetime.combine(target_date, start)
        range_end = datetime.datetime.combine(target_date, end)
        candidate = range_start
        while candidate + datetime.timedelta(minutes=session_minutes) <= range_end:
            if candidate.time() == target_time:
                fits = True
                break
            candidate += datetime.timedelta(minutes=session_minutes)
    if not fits:
        raise HTTPException(status_code=422, detail="Target slot is outside the schedule")
    cur.execute(
        "SELECT id FROM appointments WHERE doctor_id = %s AND appointment_date = %s "
        "AND appointment_time = %s AND status IN ('scheduled', 'rescheduled') "
        "AND id <> %s;",
        (doctor_id, target_date, target_time, appointment_id),
    )
    if cur.fetchone():
        raise HTTPException(status_code=409, detail="This slot is already booked")


def validate_slot_against_ranges(
    cur,
    doctor_id: int,
    appointment_id: int,
    target_date,
    target_time,
    normalized_ranges,
):
    target_dt = datetime.datetime.combine(target_date, target_time)
    if target_dt <= datetime.datetime.now():
        raise HTTPException(status_code=422, detail="Target slot must be in the future")
    if target_time.minute % 5 or target_time.second:
        raise HTTPException(status_code=422, detail="Times must be multiples of 5 minutes")
    cur.execute(
        "SELECT id FROM doctor_days_off WHERE doctor_id = %s AND off_date = %s;",
        (doctor_id, target_date),
    )
    if cur.fetchone():
        raise HTTPException(status_code=422, detail="The doctor is unavailable on this date")
    fits = False
    for day, start, end, session_minutes in normalized_ranges:
        if day != target_date.isoweekday():
            continue
        range_start = datetime.datetime.combine(target_date, start)
        range_end = datetime.datetime.combine(target_date, end)
        candidate = range_start
        while candidate + datetime.timedelta(minutes=session_minutes) <= range_end:
            if candidate.time() == target_time:
                fits = True
                break
            candidate += datetime.timedelta(minutes=session_minutes)
    if not fits:
        raise HTTPException(status_code=422, detail="Target slot is outside the proposed schedule")
    cur.execute(
        "SELECT id FROM appointments WHERE doctor_id = %s AND appointment_date = %s "
        "AND appointment_time = %s AND status IN ('scheduled', 'rescheduled') "
        "AND id <> %s;",
        (doctor_id, target_date, target_time, appointment_id),
    )
    if cur.fetchone():
        raise HTTPException(status_code=409, detail="This slot is already booked")


@app.get("/doctor/schedule")
def get_doctor_schedule(auth=Depends(require_role("doctor"))):
    conn = get_db_connection()
    cur = conn.cursor()
    cur.execute(
        "SELECT day_of_week, start_time, end_time, session_length_minutes FROM doctor_schedules "
        "WHERE doctor_id = %s ORDER BY day_of_week, start_time;",
        (auth["doctor_id"],),
    )
    rows = cur.fetchall()
    cur.close()
    conn.close()
    return [{"day_of_week": r[0], "start_time": str(r[1])[:5],
             "end_time": str(r[2])[:5], "session_length_minutes": r[3]} for r in rows]


@app.put("/doctor/schedule")
def replace_doctor_schedule(
    body: ScheduleReplaceWithResolutions,
    http_request: Request,
    auth=Depends(require_role("doctor")),
):
    normalized = []
    for item in body.ranges:
        try:
            start = datetime.time.fromisoformat(item.start_time)
            end = datetime.time.fromisoformat(item.end_time)
        except ValueError:
            raise HTTPException(status_code=422, detail="Invalid time range; use 24-hour HH:MM")
        if start >= end:
            raise HTTPException(status_code=422, detail="Start time must be before end time")
        if start.minute % 5 or end.minute % 5 or start.second or end.second:
            raise HTTPException(status_code=422, detail="Times must be multiples of 5 minutes")
        if item.session_length_minutes < 5 or item.session_length_minutes > 60:
            raise HTTPException(status_code=422, detail="Session length must be between 5 and 60 minutes")
        if item.session_length_minutes % 5:
            raise HTTPException(status_code=422, detail="Session length must be in 5-minute steps")
        session_minutes = item.session_length_minutes
        session_delta = datetime.timedelta(minutes=session_minutes)
        cursor = datetime.datetime.combine(datetime.date.today(), start)
        end_cursor = datetime.datetime.combine(datetime.date.today(), end)
        if cursor + session_delta > end_cursor:
            raise HTTPException(status_code=422, detail="Session length must fit inside the working range")
        normalized.append((item.day_of_week, start, end, session_minutes))
    for i, (day, start, end, session_minutes) in enumerate(normalized):
        for other_day, other_start, other_end, _ in normalized[i + 1:]:
            if day == other_day and start < other_end and other_start < end:
                raise HTTPException(status_code=422, detail="Overlapping schedule ranges")
    conn = get_db_connection()
    cur = conn.cursor()
    try:
        cur.execute("SELECT name FROM doctors WHERE id = %s;", (auth["doctor_id"],))
        doctor_row = cur.fetchone()
        if doctor_row is None:
            raise HTTPException(status_code=404, detail="Doctor not found")
        doctor_name = doctor_row[0]

        cur.execute(
            """SELECT a.id, a.patient_id, u.name, u.email, a.appointment_date, a.appointment_time
               FROM appointments a JOIN users u ON u.id = a.patient_id
               WHERE a.doctor_id = %s
                 AND (a.appointment_date > CURRENT_DATE
                      OR (a.appointment_date = CURRENT_DATE AND a.appointment_time > CURRENT_TIME))
                 AND a.status IN ('scheduled', 'rescheduled')
               FOR UPDATE OF a;""",
            (auth["doctor_id"],),
        )
        appointments = cur.fetchall()
        affected = []
        schedule_by_day = {}
        for day, start, end, session_minutes in normalized:
            schedule_by_day.setdefault(day, []).append((start, end, session_minutes))

        for appointment in appointments:
            appointment_id, patient_id, patient_name, patient_email, old_date, old_time = appointment
            day_ranges = schedule_by_day.get(old_date.isoweekday(), [])
            fits = False
            old_dt = datetime.datetime.combine(old_date, old_time)
            for start, end, session_minutes in day_ranges:
                range_start = datetime.datetime.combine(old_date, start)
                range_end = datetime.datetime.combine(old_date, end)
                if range_start <= old_dt < range_end:
                    slot_index = int((old_dt - range_start).total_seconds() // (session_minutes * 60))
                    slot_time = range_start + datetime.timedelta(minutes=slot_index * session_minutes)
                    if slot_time == old_dt:
                        fits = True
                        break
            if not fits:
                affected.append({
                    "id": appointment_id,
                    "patient_name": patient_name,
                    "date": str(old_date),
                    "time": str(old_time)[:5],
                })

        resolutions = {item.appointment_id: item for item in body.resolutions}
        unresolved = [item for item in affected if item["id"] not in resolutions]
        if unresolved:
            conn.rollback()
            raise HTTPException(status_code=409, detail={
                "message": "Existing appointments fall outside the proposed schedule",
                "appointments": unresolved,
            })

        for item in affected:
            resolution = resolutions[item["id"]]
            if resolution.action not in ("reschedule", "cancel"):
                raise HTTPException(status_code=422, detail="Resolution must be reschedule or cancel")
            cur.execute(
                "SELECT patient_id, appointment_date, appointment_time "
                "FROM appointments WHERE id = %s AND doctor_id = %s FOR UPDATE;",
                (item["id"], auth["doctor_id"]),
            )
            current = cur.fetchone()
            if current is None:
                raise HTTPException(status_code=404, detail="Appointment not found")
            patient_id, old_date, old_time = current
            if resolution.action == "cancel":
                cur.execute(
                    "UPDATE appointments SET status = 'cancelled_by_doctor' WHERE id = %s;",
                    (item["id"],),
                )
                message = (
                    f"{doctor_name} cancelled your appointment originally scheduled for "
                    f"{old_date} at {str(old_time)[:5]}."
                )
                cur.execute(
                    "INSERT INTO notifications (user_id, message) VALUES (%s, %s);",
                    (patient_id, message),
                )
                cur.execute(
                    "INSERT INTO email_outbox (recipient, subject, body) "
                    "SELECT email, 'Appointment cancelled', %s FROM users WHERE id = %s;",
                    (message, patient_id),
                )
                cur.execute(
                    "INSERT INTO doctor_audit_log "
                    "(doctor_id, action, affected_type, affected_id, previous_value, new_value) "
                    "VALUES (%s, 'appointment_cancelled', 'appointment', %s, %s, 'cancelled_by_doctor');",
                    (auth["doctor_id"], str(item["id"]),
                     f"{old_date} {str(old_time)[:5]}"),
                )
            else:
                if not resolution.date or not resolution.time:
                    raise HTTPException(status_code=422, detail="New date and time are required")
                try:
                    new_date = datetime.date.fromisoformat(resolution.date)
                    new_time = datetime.time.fromisoformat(resolution.time)
                except ValueError:
                    raise HTTPException(status_code=422, detail="Invalid new date or time")
                validate_slot_against_ranges(
                    cur,
                    auth["doctor_id"],
                    item["id"],
                    new_date,
                    new_time,
                    normalized,
                )
                cur.execute(
                    """UPDATE appointments
                       SET rescheduled_from_date = %s, rescheduled_from_time = %s,
                           appointment_date = %s, appointment_time = %s, status = 'rescheduled'
                       WHERE id = %s;""",
                    (old_date, old_time, new_date, new_time, item["id"]),
                )
                message = (
                    f"{doctor_name} rescheduled your appointment from "
                    f"{old_date} at {str(old_time)[:5]} to "
                    f"{new_date} at {str(new_time)[:5]}."
                )
                cur.execute(
                    "INSERT INTO notifications (user_id, message) VALUES (%s, %s);",
                    (patient_id, message),
                )
                cur.execute(
                    "INSERT INTO email_outbox (recipient, subject, body) "
                    "SELECT email, 'Appointment rescheduled', %s FROM users WHERE id = %s;",
                    (message, patient_id),
                )
                cur.execute(
                    "INSERT INTO doctor_audit_log "
                    "(doctor_id, action, affected_type, affected_id, previous_value, new_value) "
                    "VALUES (%s, 'appointment_rescheduled', 'appointment', %s, %s, %s);",
                    (auth["doctor_id"], str(item["id"]),
                     f"{old_date} {str(old_time)[:5]}",
                     f"{new_date} {str(new_time)[:5]}"),
                )

        cur.execute("DELETE FROM doctor_schedules WHERE doctor_id = %s;", (auth["doctor_id"],))
        for day, start, end, session_minutes in normalized:
            cur.execute(
                """INSERT INTO doctor_schedules
                   (doctor_id, day_of_week, start_time, end_time, session_length_minutes)
                   VALUES (%s, %s, %s, %s, %s);""",
                (auth["doctor_id"], day, start, end, session_minutes),
            )
        cur.execute(
            "INSERT INTO doctor_audit_log "
            "(doctor_id, action, affected_type, affected_id, previous_value, new_value) "
            "VALUES (%s, 'schedule_updated', 'schedule', 'weekly', 'previous schedule', %s);",
            (auth["doctor_id"], str([(d, str(s)[:5], str(e)[:5], m) for d, s, e, m in normalized]))
        )
        conn.commit()
    except HTTPException:
        conn.rollback()
        raise
    except psycopg2.errors.UniqueViolation:
        conn.rollback()
        raise HTTPException(status_code=409, detail="A slot is already booked")
    finally:
        cur.close()
        conn.close()
    return {"message": "Schedule updated"}


@app.get("/doctor/free-slots")
def doctor_free_slots(date: str, auth=Depends(require_role("doctor"))):
    try:
        target_date = datetime.date.fromisoformat(date)
    except ValueError:
        raise HTTPException(status_code=422, detail="Date must use YYYY-MM-DD")
    conn = get_db_connection()
    cur = conn.cursor()
    cur.execute(
        "SELECT id FROM doctor_days_off WHERE doctor_id = %s AND off_date = %s;",
        (auth["doctor_id"], target_date),
    )
    if cur.fetchone():
        cur.close()
        conn.close()
        return {"date": date, "slots": []}
    cur.execute(
        "SELECT start_time, end_time, session_length_minutes FROM doctor_schedules "
        "WHERE doctor_id = %s AND day_of_week = %s;",
        (auth["doctor_id"], target_date.isoweekday()),
    )
    schedules = cur.fetchall()
    slots = []
    for start, end, session_minutes in schedules:
        current = datetime.datetime.combine(target_date, start)
        end_dt = datetime.datetime.combine(target_date, end)
        while current + datetime.timedelta(minutes=session_minutes) <= end_dt:
            if datetime.datetime.combine(target_date, current.time()) > datetime.datetime.now():
                slots.append(current.strftime("%H:%M"))
            current += datetime.timedelta(minutes=session_minutes)
    cur.execute(
        "SELECT appointment_time FROM appointments WHERE doctor_id = %s "
        "AND appointment_date = %s AND status IN ('scheduled', 'rescheduled');",
        (auth["doctor_id"], target_date),
    )
    booked = {str(row[0])[:5] for row in cur.fetchall()}
    cur.close()
    conn.close()
    return {"date": date, "slots": sorted(set(slots) - booked)}


@app.get("/doctor/days-off")
def list_doctor_days_off(auth=Depends(require_role("doctor"))):
    conn = get_db_connection()
    cur = conn.cursor()
    cur.execute(
        "SELECT id, off_date, reason, created_at FROM doctor_days_off "
        "WHERE doctor_id = %s ORDER BY off_date;",
        (auth["doctor_id"],),
    )
    rows = cur.fetchall()
    cur.close()
    conn.close()
    return [{"id": r[0], "date": str(r[1]), "reason": r[2], "created_at": r[3]} for r in rows]


@app.post("/doctor/days-off")
def create_doctor_day_off(
    body: DayOffCreateWithResolutions,
    http_request: Request,
    auth=Depends(require_role("doctor")),
):
    try:
        off_date = datetime.date.fromisoformat(body.date)
    except ValueError:
        raise HTTPException(status_code=422, detail="Date must use YYYY-MM-DD")
    if off_date < datetime.date.today():
        raise HTTPException(status_code=422, detail="Day off must be in the future")
    conn = get_db_connection()
    cur = conn.cursor()
    try:
        cur.execute(
            "SELECT id FROM doctor_days_off WHERE doctor_id = %s AND off_date = %s;",
            (auth["doctor_id"], off_date),
        )
        if cur.fetchone():
            raise HTTPException(status_code=409, detail="This date is already a day off")
        cur.execute(
            """SELECT a.id, a.patient_id, u.name, a.appointment_time
               FROM appointments a JOIN users u ON u.id = a.patient_id
               WHERE a.doctor_id = %s AND a.appointment_date = %s
                 AND a.status IN ('scheduled', 'rescheduled')
               FOR UPDATE OF a;""",
            (auth["doctor_id"], off_date),
        )
        appointments = cur.fetchall()
        if appointments and not body.cancel_all:
            resolution_map = {item.appointment_id: item for item in body.resolutions}
            unresolved = [appointment[0] for appointment in appointments if appointment[0] not in resolution_map]
            if unresolved:
                raise HTTPException(status_code=409, detail={
                    "message": "Affected appointments must be resolved",
                    "appointments": [
                        {"id": appointment[0], "patient_name": appointment[2],
                         "date": str(off_date), "time": str(appointment[3])[:5]}
                        for appointment in appointments
                    ],
                })
        cur.execute("SELECT name FROM doctors WHERE id = %s;", (auth["doctor_id"],))
        doctor_row = cur.fetchone()
        doctor_name = doctor_row[0] if doctor_row else "Your doctor"

        if body.cancel_all:
            for appointment_id, patient_id, patient_name, old_time in appointments:
                message = (
                    f"{doctor_name} cancelled your appointment scheduled for "
                    f"{off_date} at {str(old_time)[:5]}."
                )
                cur.execute(
                    "UPDATE appointments SET status = 'cancelled_by_doctor' WHERE id = %s;",
                    (appointment_id,),
                )
                cur.execute("INSERT INTO notifications (user_id, message) VALUES (%s, %s);",
                            (patient_id, message))
                cur.execute(
                    "INSERT INTO email_outbox (recipient, subject, body) "
                    "SELECT email, 'Appointment cancelled', %s FROM users WHERE id = %s;",
                    (message, patient_id),
                )
                cur.execute(
                    "INSERT INTO doctor_audit_log "
                    "(doctor_id, action, affected_type, affected_id, previous_value, new_value) "
                    "VALUES (%s, 'appointment_cancelled_for_day_off', 'appointment', %s, %s, 'cancelled_by_doctor');",
                    (auth["doctor_id"], str(appointment_id), f"{off_date} {str(old_time)[:5]}"),
                )
        else:
            for appointment_id, patient_id, patient_name, old_time in appointments:
                resolution = resolution_map[appointment_id]
                if resolution.action == "cancel":
                    message = (
                        f"{doctor_name} cancelled your appointment scheduled for "
                        f"{off_date} at {str(old_time)[:5]}."
                    )
                    cur.execute(
                        "UPDATE appointments SET status = 'cancelled_by_doctor' WHERE id = %s;",
                        (appointment_id,),
                    )
                    cur.execute("INSERT INTO notifications (user_id, message) VALUES (%s, %s);",
                                (patient_id, message))
                    cur.execute(
                        "INSERT INTO email_outbox (recipient, subject, body) "
                        "SELECT email, 'Appointment cancelled', %s FROM users WHERE id = %s;",
                        (message, patient_id),
                    )
                    cur.execute(
                        "INSERT INTO doctor_audit_log "
                        "(doctor_id, action, affected_type, affected_id, previous_value, new_value) "
                        "VALUES (%s, 'appointment_cancelled_for_day_off', 'appointment', %s, %s, 'cancelled_by_doctor');",
                        (auth["doctor_id"], str(appointment_id), f"{off_date} {str(old_time)[:5]}"),
                    )
                elif resolution.action == "reschedule":
                    if not resolution.date or not resolution.time:
                        raise HTTPException(status_code=422, detail="New date and time are required")
                    try:
                        new_date = datetime.date.fromisoformat(resolution.date)
                        new_time = datetime.time.fromisoformat(resolution.time)
                    except ValueError:
                        raise HTTPException(status_code=422, detail="Invalid new date or time")
                    validate_slot(cur, auth["doctor_id"], appointment_id, new_date, new_time)
                    cur.execute(
                        """UPDATE appointments
                           SET rescheduled_from_date = %s, rescheduled_from_time = %s,
                               appointment_date = %s, appointment_time = %s, status = 'rescheduled'
                           WHERE id = %s;""",
                        (off_date, old_time, new_date, new_time, appointment_id),
                    )
                    message = (
                        f"{doctor_name} rescheduled your appointment from "
                        f"{off_date} at {str(old_time)[:5]} to "
                        f"{new_date} at {str(new_time)[:5]}."
                    )
                    cur.execute("INSERT INTO notifications (user_id, message) VALUES (%s, %s);",
                                (patient_id, message))
                    cur.execute(
                        "INSERT INTO email_outbox (recipient, subject, body) "
                        "SELECT email, 'Appointment rescheduled', %s FROM users WHERE id = %s;",
                        (message, patient_id),
                    )
                    cur.execute(
                        "INSERT INTO doctor_audit_log "
                        "(doctor_id, action, affected_type, affected_id, previous_value, new_value) "
                        "VALUES (%s, 'appointment_rescheduled_for_day_off', 'appointment', %s, %s, %s);",
                        (auth["doctor_id"], str(appointment_id),
                         f"{off_date} {str(old_time)[:5]}",
                         f"{new_date} {str(new_time)[:5]}"),
                    )
                else:
                    raise HTTPException(status_code=422, detail="Resolution must be reschedule or cancel")

        cur.execute(
            """INSERT INTO doctor_days_off (doctor_id, off_date, reason)
               VALUES (%s, %s, %s);""",
            (auth["doctor_id"], off_date, body.reason),
        )
        cur.execute(
            "INSERT INTO doctor_audit_log "
            "(doctor_id, action, affected_type, affected_id, previous_value, new_value) "
            "VALUES (%s, 'day_off_created', 'day_off', %s, NULL, %s);",
            (auth["doctor_id"], str(off_date), body.reason or "unavailable"),
        )
        conn.commit()
    except HTTPException:
        conn.rollback()
        raise
    except psycopg2.errors.UniqueViolation:
        conn.rollback()
        raise HTTPException(status_code=409, detail="This date is already a day off")
    finally:
        cur.close()
        conn.close()
    return {"message": "Day off saved"}


@app.delete("/doctor/days-off/{date}")
def remove_doctor_day_off(
    date: str,
    http_request: Request,
    auth=Depends(require_role("doctor")),
):
    try:
        off_date = datetime.date.fromisoformat(date)
    except ValueError:
        raise HTTPException(status_code=422, detail="Date must use YYYY-MM-DD")
    conn = get_db_connection()
    cur = conn.cursor()
    cur.execute(
        "DELETE FROM doctor_days_off WHERE doctor_id = %s AND off_date = %s RETURNING id;",
        (auth["doctor_id"], off_date),
    )
    row = cur.fetchone()
    if row is None:
        cur.close()
        conn.close()
        raise HTTPException(status_code=404, detail="Day off not found")
    cur.execute(
        "INSERT INTO doctor_audit_log "
        "(doctor_id, action, affected_type, affected_id, previous_value, new_value) "
        "VALUES (%s, 'day_off_removed', 'day_off', %s, %s, NULL);",
        (auth["doctor_id"], str(off_date), str(off_date)),
    )
    conn.commit()
    cur.close()
    conn.close()
    return {"message": "Day off removed"}

@app.put("/doctor/appointments/{appointment_id}/reschedule")
def reschedule_appointment(appointment_id: int, body: Reschedule, http_request: Request, auth=Depends(require_role("doctor"))):
    try:
        target_date = datetime.date.fromisoformat(body.date)
        target_time = datetime.time.fromisoformat(body.time)
    except ValueError:
        raise HTTPException(status_code=422, detail="Invalid date or time")
    target_dt = datetime.datetime.combine(target_date, target_time)
    if target_dt <= datetime.datetime.now():
        raise HTTPException(status_code=422, detail="Target slot must be in the future")

    conn = get_db_connection()
    cur = conn.cursor()
    cur.execute("SELECT doctor_id FROM appointments WHERE id = %s;", (appointment_id,))
    owner = cur.fetchone()
    if owner is None:
        cur.close()
        conn.close()
        raise HTTPException(status_code=404, detail="Appointment not found")
    if owner[0] != auth["doctor_id"]:
        cur.close()
        conn.close()
        raise HTTPException(status_code=403, detail="Forbidden")
    cur.execute(
        "SELECT id, patient_id, appointment_date, appointment_time FROM appointments "
        "WHERE id = %s AND doctor_id = %s FOR UPDATE;",
        (appointment_id, auth["doctor_id"]),
    )
    appointment = cur.fetchone()
    if appointment is None:
        cur.close()
        conn.close()
        raise HTTPException(status_code=404, detail="Appointment not found")
    validate_slot(cur, auth["doctor_id"], appointment_id, target_date, target_time)
    cur.execute("SELECT name FROM doctors WHERE id = %s;", (auth["doctor_id"],))
    doctor_row = cur.fetchone()
    doctor_name = doctor_row[0] if doctor_row else "Your doctor"
    old_date = appointment[2]
    old_time = appointment[3]

    cur.execute(
        """UPDATE appointments
           SET rescheduled_from_date = %s, rescheduled_from_time = %s,
               appointment_date = %s, appointment_time = %s, status = 'rescheduled'
           WHERE id = %s
           RETURNING id;""",
        (old_date, old_time, target_date, target_time, appointment_id),
    )
    message = (
        f"{doctor_name} rescheduled your appointment from "
        f"{old_date} at {str(old_time)[:5]} to "
        f"{target_date} at {str(target_time)[:5]}."
    )
    cur.execute(
        "INSERT INTO notifications (user_id, message) VALUES (%s, %s);",
        (appointment[1], message),
    )
    cur.execute(
        "INSERT INTO email_outbox (recipient, subject, body) "
        "SELECT email, 'Appointment rescheduled', %s FROM users WHERE id = %s;",
        (message, appointment[1]),
    )
    cur.execute(
        "INSERT INTO doctor_audit_log "
        "(doctor_id, action, affected_type, affected_id, previous_value, new_value) "
        "VALUES (%s, 'appointment_rescheduled', 'appointment', %s, %s, %s);",
        (auth["doctor_id"], str(appointment_id),
         f"{old_date} {str(old_time)[:5]}",
         f"{target_date} {str(target_time)[:5]}"),
    )
    audit(cur, auth["id"], "appointment_rescheduled", "appointment", appointment_id, http_request.client.host if http_request.client else None)
    try:
        conn.commit()
    except psycopg2.errors.UniqueViolation:
        conn.rollback()
        cur.close()
        conn.close()
        raise HTTPException(status_code=409, detail="This slot is already booked")
    cur.close()
    conn.close()
    return {"message": "Appointment rescheduled"}


@app.put("/doctor/appointments/{appointment_id}/care-notes")
def update_doctor_care_notes(
    appointment_id: int,
    care_note: AppointmentCareNoteUpdate,
    http_request: Request,
    auth=Depends(require_role("doctor")),
):
    advice = care_note.doctor_advice.strip() if care_note.doctor_advice else None
    revisit_notes = care_note.revisit_notes.strip() if care_note.revisit_notes else None
    revisit_date = None
    if care_note.revisit_date:
        try:
            revisit_date = datetime.date.fromisoformat(care_note.revisit_date)
        except ValueError:
            raise HTTPException(status_code=422, detail="Revisit date must use YYYY-MM-DD")
    conn = get_db_connection()
    cur = conn.cursor()
    cur.execute(
        "SELECT appointment_date FROM appointments "
        "WHERE id = %s AND doctor_id = %s;",
        (appointment_id, auth["doctor_id"]),
    )
    appointment = cur.fetchone()
    if appointment is None:
        cur.close()
        conn.close()
        raise HTTPException(status_code=404, detail="Appointment not found")
    if appointment[0] > datetime.date.today():
        cur.close()
        conn.close()
        raise HTTPException(status_code=400, detail="Care notes can be added after the appointment date")
    if revisit_date is not None and revisit_date < appointment[0]:
        cur.close()
        conn.close()
        raise HTTPException(status_code=422, detail="Revisit date cannot be before the appointment")
    cur.execute(
        "UPDATE appointments SET doctor_advice = %s, revisit_date = %s, revisit_notes = %s "
        "WHERE id = %s AND doctor_id = %s;",
        (advice, revisit_date, revisit_notes, appointment_id, auth["doctor_id"]),
    )
    audit(cur, auth["id"], "appointment_care_notes_updated", "appointment", appointment_id,
          http_request.client.host if http_request.client else None)
    conn.commit()
    cur.close()
    conn.close()
    return {"message": "Care notes saved"}


@app.delete("/doctor/appointments/{appointment_id}")
def cancel_appointment_by_doctor(appointment_id: int, http_request: Request, auth=Depends(require_role("doctor"))):
    conn = get_db_connection()
    cur = conn.cursor()
    cur.execute("SELECT doctor_id FROM appointments WHERE id = %s;", (appointment_id,))
    owner = cur.fetchone()
    if owner is None:
        cur.close()
        conn.close()
        raise HTTPException(status_code=404, detail="Appointment not found")
    if owner[0] != auth["doctor_id"]:
        cur.close()
        conn.close()
        raise HTTPException(status_code=403, detail="Forbidden")
    cur.execute(
        "SELECT patient_id, appointment_date, appointment_time FROM appointments "
        "WHERE id = %s AND doctor_id = %s FOR UPDATE;",
        (appointment_id, auth["doctor_id"]),
    )
    row = cur.fetchone()
    if row is None:
        cur.close()
        conn.close()
        raise HTTPException(status_code=404, detail="Appointment not found")
    cur.execute("SELECT name FROM doctors WHERE id = %s;", (auth["doctor_id"],))
    doctor_row = cur.fetchone()
    doctor_name = doctor_row[0] if doctor_row else "Your doctor"
    old_date = row[1]
    old_time = row[2]
    message = (
        f"{doctor_name} cancelled your appointment scheduled for "
        f"{old_date} at {str(old_time)[:5]}."
    )
    cur.execute(
        "UPDATE appointments SET status = 'cancelled_by_doctor' WHERE id = %s;",
        (appointment_id,),
    )
    cur.execute("INSERT INTO notifications (user_id, message) VALUES (%s, %s);", (row[0], message))
    cur.execute(
        "INSERT INTO email_outbox (recipient, subject, body) "
        "SELECT email, 'Appointment cancelled', %s FROM users WHERE id = %s;",
        (message, row[0]),
    )
    cur.execute(
        "INSERT INTO doctor_audit_log "
        "(doctor_id, action, affected_type, affected_id, previous_value, new_value) "
        "VALUES (%s, 'appointment_cancelled', 'appointment', %s, %s, 'cancelled_by_doctor');",
        (auth["doctor_id"], str(appointment_id), f"{old_date} {str(old_time)[:5]}"),
    )
    audit(cur, auth["id"], "appointment_cancelled_by_doctor", "appointment", appointment_id, http_request.client.host if http_request.client else None)
    conn.commit()
    cur.close()
    conn.close()
    return {"message": "Appointment cancelled"}


@app.get("/notifications")
def get_notifications(auth=Depends(get_authenticated_user)):
    conn = get_db_connection()
    cur = conn.cursor()
    cur.execute(
        "SELECT id, message, created_at, read_at FROM notifications "
        "WHERE user_id = %s ORDER BY created_at DESC;",
        (auth["id"],),
    )
    rows = cur.fetchall()
    cur.close()
    conn.close()
    return [{"id": r[0], "message": r[1], "created_at": r[2], "read_at": r[3]} for r in rows]


@app.post("/notifications/{notification_id}/read")
def mark_notification_read(notification_id: int, auth=Depends(get_authenticated_user)):
    conn = get_db_connection()
    cur = conn.cursor()
    cur.execute(
        "UPDATE notifications SET read_at = CURRENT_TIMESTAMP "
        "WHERE id = %s AND user_id = %s;",
        (notification_id, auth["id"]),
    )
    conn.commit()
    cur.close()
    conn.close()
    return {"message": "Notification marked read"}


@app.get("/admin/audit")
def list_admin_audit(auth=Depends(require_role("admin"))):
    conn = get_db_connection()
    cur = conn.cursor()
    cur.execute(
        "SELECT id, administrator_id, action, target_type, target_id, ip_address, created_at "
        "FROM admin_audit_log ORDER BY created_at DESC LIMIT 500;"
    )
    rows = cur.fetchall()
    cur.close()
    conn.close()
    return [{"id": r[0], "administrator_id": r[1], "action": r[2], "target_type": r[3],
             "target_id": r[4], "ip_address": r[5], "created_at": r[6]} for r in rows]


if __name__ == "__main__":
    import uvicorn

    port = int(os.environ.get("PORT", 5000))
    uvicorn.run(app, host="0.0.0.0", port=port)
