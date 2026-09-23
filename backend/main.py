from fastapi.middleware.cors import CORSMiddleware
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from fastapi import Depends
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from .database import get_db_connection
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
