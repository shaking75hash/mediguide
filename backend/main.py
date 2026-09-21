from fastapi import FastAPI, HTTPException
from pydantic import BaseModel # 1. Import BaseModel for data validation

app = FastAPI()

doctors = [
    {
        "id": 1,
        "name": "Dr. Rahman",
        "specialty": "Cardiologist",
        "location": "Rajshahi",
        "fee": 800
    },
    {
        "id": 2,
        "name": "Dr. Karim",
        "specialty": "Neurologist",
        "location": "Rajshahi",
        "fee": 1000
    },
    {
        "id": 3,
        "name": "Dr. Ahmed",
        "specialty": "Dermatologist",
        "location": "Dhaka",
        "fee": 600
    }
]

# 2. Define the Blueprint for creating a NEW doctor
class DoctorCreate(BaseModel):
    name: str
    specialty: str
    location: str
    fee: int

@app.get("/")
def home():
    return {"message": "MediGuide Backend is running"}

@app.get("/doctors")
def get_doctors():
    return doctors

@app.get("/doctors/{doctor_id}")
def get_single_doctor(doctor_id: int):
    for doctor in doctors:
        if doctor["id"] == doctor_id:
            return doctor
    raise HTTPException(status_code=404, detail="Doctor not found")

# --- NEW POST ENDPOINT ---
# Notice we add status_code=201. We will explain why below!
@app.post("/doctors", status_code=201)
def create_doctor(new_doctor: DoctorCreate):

    # 1. Generate a new ID (Since we are using a list, we just add 1 to the highest current ID)
    new_id = max([doc["id"] for doc in doctors]) + 1

    # 2. Convert the Pydantic model into a standard Python dictionary
    doctor_dict = new_doctor.model_dump()

    # 3. Add the new ID to the dictionary
    doctor_dict["id"] = new_id

    # 4. Add the new doctor to our temporary database list
    doctors.append(doctor_dict)

    # 5. Return the fully created doctor
    return doctor_dict
# --- NEW DELETE ENDPOINT ---
@app.delete("/doctors/{doctor_id}")
def delete_doctor(doctor_id: int):

    # enumerate() gives us both the index (position) and the doctor dictionary
    for index, doctor in enumerate(doctors):

        if doctor["id"] == doctor_id:
            # .pop(index) removes the item at that specific position from the list
            # and returns it so we can show the user what was deleted.
            deleted_doctor = doctors.pop(index)
            return {"message": "Doctor deleted successfully", "deleted_data": deleted_doctor}

    # If the loop finishes and we didn't return, the ID doesn't exist.
    raise HTTPException(status_code=404, detail="Doctor not found")
