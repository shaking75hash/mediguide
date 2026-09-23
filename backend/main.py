from fastapi.middleware.cors import CORSMiddleware
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from fastapi import Depends
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from .database import get_db_connection
from typing import Optional
import bcrypt
import jwt
import datetime
import os

app = FastAPI()

# ✅ Allow Flutter Web (Chrome) to talk to this backend
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)
SECRET_KEY = os.getenv("SECRET_KEY")


class DoctorCreate(BaseModel):
    name: str
    specialty: str
    location: str
    fee: int

class UserCreate(BaseModel):
    name: str
    email: str
    password: str

class UserLogin(BaseModel):
    email: str
    password: str

class HealthRecordCreate(BaseModel):
    blood_pressure: Optional[str] = None
    blood_sugar: Optional[float] = None
    weight: Optional[float] = None
    notes: Optional[str] = None

def create_access_token(user_id: int):
    # What data do we want to put inside the keycard?
    payload = {
        "user_id": user_id,
        # Make the token expire in 30 minutes from now
        "exp": datetime.datetime.now(datetime.timezone.utc) + datetime.timedelta(minutes=30)
    }

    # Encode the payload into a JWT string using our secret key
    token = jwt.encode(payload, SECRET_KEY, algorithm="HS256")
    return token
# This tells FastAPI: "The key to get a token is found at the /login endpoint"
security = HTTPBearer()

def get_current_user(credentials: HTTPAuthorizationCredentials = Depends(security)):
    credentials_exception = HTTPException(
        status_code=401,
        detail="Could not validate credentials",
        headers={"WWW-Authenticate": "Bearer"},
    )

    # 🔍 DEBUG: What did the Bouncer receive?
    if not credentials:
        print("❌ BOUNCER: No Authorization header received at all!")
        raise credentials_exception

    token = credentials.credentials
    print(f"🔍 BOUNCER: Received token starting with: {token[:25]}...")
    print(f"🔍 BOUNCER: SECRET_KEY loaded = {SECRET_KEY is not None} (value: {str(SECRET_KEY)[:6]}...)")

    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=["HS256"])
        print(f"✅ BOUNCER: Token decoded! Payload = {payload}")
        user_id: int = payload.get("user_id")
        if user_id is None:
            print("❌ BOUNCER: Token has no user_id!")
            raise credentials_exception
        return user_id
    except jwt.ExpiredSignatureError:
        print("❌ BOUNCER: Token is EXPIRED!")
        raise HTTPException(status_code=401, detail="Token has expired")
    except jwt.InvalidTokenError as e:
        print(f"❌ BOUNCER: Token INVALID → {e}")
        raise credentials_exception

@app.get("/me")
def get_me(current_user_id: int = Depends(get_current_user)):
    conn = get_db_connection()
    cur = conn.cursor()
    cur.execute("SELECT id, name, email FROM users WHERE id = %s;", (current_user_id,))
    row = cur.fetchone()
    cur.close()
    conn.close()

    if row is None:
        raise HTTPException(status_code=404, detail="User not found")

    return {
        "id": row[0],
        "name": row[1],
        "email": row[2],
        "message": f"Welcome back, {row[1]}! Your token is valid."
    }

@app.get("/")
def home():
    return {"message": "MediGuide Backend is secure and organized!"}

@app.get("/doctors")
def get_doctors():
    conn = get_db_connection()
    cur = conn.cursor()
    cur.execute("SELECT id, name, specialty, location, consultation_fee, is_verified FROM doctors;")
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
def search_doctors(query: str = ""):
    conn = get_db_connection()
    cur = conn.cursor()

    search_term = f"%{query}%"
    cur.execute(
        "SELECT id, name, specialty, location, consultation_fee, is_verified "
        "FROM doctors "
        "WHERE name ILIKE %s OR specialty ILIKE %s OR location ILIKE %s;",
        (search_term, search_term, search_term),
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

@app.get("/price-comparison")
def get_price_comparison(service_id: int):
    conn = get_db_connection()
    cur = conn.cursor()
    cur.execute(
        """SELECT name, specialty, location, consultation_fee
           FROM doctors ORDER BY consultation_fee ASC;"""
    )
    rows = cur.fetchall()
    cur.close()
    conn.close()

    return {
        "service_id": service_id,
        "providers": [
            {
                "doctor_name": row[0],
                "specialty": row[1],
                "location": row[2],
                "price": row[3],
            }
            for row in rows
        ],
    }

@app.get("/doctors/{doctor_id}")
def get_single_doctor(doctor_id: int):
    conn = get_db_connection()
    cur = conn.cursor()
    cur.execute("SELECT id, name, specialty, location, consultation_fee, is_verified FROM doctors WHERE id = %s;", (doctor_id,))
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
        WHERE d.id = %s;
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
        AND status = 'scheduled';
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

@app.post("/doctors", status_code=201)
def create_doctor(new_doctor: DoctorCreate, current_user_id: int = Depends(get_current_user)):

    # ✅ Look at your terminal when you run this!
    print(f"🔒 SECURE ACTION: User ID {current_user_id} is adding a doctor.")

    conn = get_db_connection()
    cur = conn.cursor()


    cur.execute(
        "INSERT INTO doctors (name, specialty, location, consultation_fee) VALUES (%s, %s, %s, %s) RETURNING id, name, specialty, location, consultation_fee, is_verified;",
        (new_doctor.name, new_doctor.specialty, new_doctor.location, new_doctor.fee)
    )
    row = cur.fetchone()
    conn.commit()
    cur.close()
    conn.close()

    return {
        "id": row[0], "name": row[1], "specialty": row[2],
        "location": row[3], "consultation_fee": row[4], "is_verified": row[5]
    }

@app.delete("/doctors/{doctor_id}")
def delete_doctor(doctor_id: int):
    conn = get_db_connection()
    cur = conn.cursor()
    cur.execute("SELECT id FROM doctors WHERE id = %s;", (doctor_id,))
    if cur.fetchone() is None:
        cur.close()
        conn.close()
        raise HTTPException(status_code=404, detail="Doctor not found")

    cur.execute("DELETE FROM doctors WHERE id = %s;", (doctor_id,))
    conn.commit()
    cur.close()
    conn.close()
    return {"message": "Doctor deleted successfully", "deleted_id": doctor_id}

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
        INSERT INTO users (name, email, password_hash)
        VALUES (%s, %s, %s)
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
def login_user(credentials: UserLogin):
    conn = get_db_connection()
    cur = conn.cursor()

    cur.execute("SELECT id, name, password_hash FROM users WHERE email = %s;", (credentials.email,))
    user_row = cur.fetchone()
    cur.close()
    conn.close()

    if user_row is None:
        raise HTTPException(status_code=401, detail="Invalid email or password")

    # ✅ MODERN BCRYPT:
    # 1. Convert the typed password to bytes
    typed_password_bytes = credentials.password.encode('utf-8')

    # 2. Get the hash from the database (it's a string) and convert it to bytes
    db_hash_bytes = user_row[2].encode('utf-8')

    # 3. Compare them!
    is_password_correct = bcrypt.checkpw(typed_password_bytes, db_hash_bytes)

    # ✅ NEW: Generate the JWT Keycard!
    access_token = create_access_token(user_row[0])

    return {
        "access_token": access_token,
        "token_type": "bearer",
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

    # Find the doctor's working hours for that weekday
    cur.execute(
        "SELECT start_time, end_time FROM doctor_schedules WHERE doctor_id = %s AND day_of_week = %s;",
        (doctor_id, weekday),
    )
    schedule = cur.fetchone()
    if not schedule:
        cur.close(); conn.close()
        return {"date": date, "slots": []}  # doctor off that day

    start_t = schedule[0]
    end_t = schedule[1]

    # Build every 30-minute slot
    all_slots = []
    current = datetime.datetime.combine(target_date, start_t)
    end_dt = datetime.datetime.combine(target_date, end_t)
    while current + datetime.timedelta(minutes=30) <= end_dt:
        all_slots.append(current.strftime("%H:%M"))
        current += datetime.timedelta(minutes=30)

    # Remove already-booked slots
    cur.execute(
        "SELECT appointment_time::text FROM appointments WHERE doctor_id = %s AND appointment_date = %s;",
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

    # Prevent double-booking
    cur.execute(
        "SELECT id FROM appointments WHERE doctor_id = %s AND appointment_date = %s AND appointment_time = %s;",
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
