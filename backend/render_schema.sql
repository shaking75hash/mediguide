CREATE TABLE IF NOT EXISTS users (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    password_hash TEXT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

ALTER TABLE users ADD COLUMN IF NOT EXISTS blood_group VARCHAR(3);
ALTER TABLE users ADD COLUMN IF NOT EXISTS height_cm NUMERIC(5, 2);
ALTER TABLE users ADD COLUMN IF NOT EXISTS weight_kg NUMERIC(5, 2);
ALTER TABLE users ADD COLUMN IF NOT EXISTS medical_history TEXT;

CREATE TABLE IF NOT EXISTS doctors (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    specialty VARCHAR(100) NOT NULL,
    location VARCHAR(100) NOT NULL,
    consultation_fee INTEGER NOT NULL,
    is_verified BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS doctor_schedules (
    id SERIAL PRIMARY KEY,
    doctor_id INTEGER NOT NULL REFERENCES doctors(id) ON DELETE CASCADE,
    day_of_week INTEGER NOT NULL CHECK (day_of_week BETWEEN 1 AND 7),
    start_time TIME NOT NULL,
    end_time TIME NOT NULL,
    UNIQUE (doctor_id, day_of_week)
);

CREATE TABLE IF NOT EXISTS appointments (
    id SERIAL PRIMARY KEY,
    patient_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    doctor_id INTEGER NOT NULL REFERENCES doctors(id) ON DELETE CASCADE,
    appointment_date DATE NOT NULL,
    appointment_time TIME NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'scheduled',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    UNIQUE (doctor_id, appointment_date, appointment_time)
);

CREATE TABLE IF NOT EXISTS doctor_trust_profiles (
    id SERIAL PRIMARY KEY,
    doctor_id INTEGER UNIQUE REFERENCES doctors(id) ON DELETE CASCADE,
    overall_score NUMERIC DEFAULT 0,
    review_score NUMERIC DEFAULT 0,
    accreditation_score NUMERIC DEFAULT 0,
    infrastructure_score NUMERIC DEFAULT 0,
    outcome_score NUMERIC DEFAULT 0,
    total_reviews INTEGER DEFAULT 0,
    verified_reviews INTEGER DEFAULT 0,
    last_updated TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS accreditations (
    id SERIAL PRIMARY KEY,
    doctor_id INTEGER REFERENCES doctors(id) ON DELETE CASCADE,
    body VARCHAR(255),
    level VARCHAR(100),
    valid_until DATE,
    is_active BOOLEAN DEFAULT TRUE
);

CREATE TABLE IF NOT EXISTS patient_reviews (
    id SERIAL PRIMARY KEY,
    doctor_id INTEGER REFERENCES doctors(id) ON DELETE CASCADE,
    patient_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
    appointment_id INTEGER REFERENCES appointments(id) ON DELETE SET NULL,
    rating INTEGER CHECK (rating BETWEEN 1 AND 5),
    comment TEXT,
    is_verified BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS medical_services (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    category VARCHAR(100),
    description TEXT
);

CREATE TABLE IF NOT EXISTS provider_prices (
    id SERIAL PRIMARY KEY,
    doctor_id INTEGER REFERENCES doctors(id) ON DELETE CASCADE,
    service_id INTEGER REFERENCES medical_services(id) ON DELETE CASCADE,
    price NUMERIC NOT NULL,
    UNIQUE (doctor_id, service_id)
);

CREATE TABLE IF NOT EXISTS diagnostic_facilities (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL UNIQUE,
    category VARCHAR(100) NOT NULL,
    location VARCHAR(100) NOT NULL,
    is_sample BOOLEAN NOT NULL DEFAULT TRUE
);

CREATE TABLE IF NOT EXISTS facility_service_prices (
    id SERIAL PRIMARY KEY,
    facility_id INTEGER NOT NULL REFERENCES diagnostic_facilities(id) ON DELETE CASCADE,
    service_id INTEGER NOT NULL REFERENCES medical_services(id) ON DELETE CASCADE,
    price NUMERIC NOT NULL CHECK (price >= 0),
    UNIQUE (facility_id, service_id)
);

CREATE TABLE IF NOT EXISTS patient_records (
    id SERIAL PRIMARY KEY,
    user_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
    record_date DATE DEFAULT CURRENT_DATE,
    blood_pressure VARCHAR(100),
    blood_sugar NUMERIC,
    weight NUMERIC,
    notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO medical_services (name, category, description)
SELECT service.name, service.category, service.description
FROM (VALUES
    ('Complete Blood Count (CBC)', 'Laboratory', 'Sample catalogue service; confirm availability and price with the facility.'),
    ('ECG (Electrocardiogram)', 'Cardiology', 'Sample catalogue service; confirm availability and price with the facility.'),
    ('X-Ray (Chest)', 'Imaging', 'Sample catalogue service; confirm availability and price with the facility.'),
    ('Ultrasound (Abdomen)', 'Imaging', 'Sample catalogue service; confirm availability and price with the facility.')
) AS service(name, category, description)
WHERE NOT EXISTS (
    SELECT 1 FROM medical_services existing WHERE lower(existing.name) = lower(service.name)
);

INSERT INTO diagnostic_facilities (name, category, location, is_sample)
VALUES
    ('Sample Padma Diagnostic Centre', 'Diagnostic Centre', 'Rajshahi', TRUE),
    ('Sample Rajshahi General Hospital', 'Hospital', 'Rajshahi', TRUE),
    ('Sample North Bengal Medical Centre', 'Hospital & Diagnostic Centre', 'Rajshahi', TRUE)
ON CONFLICT (name) DO NOTHING;

INSERT INTO facility_service_prices (facility_id, service_id, price)
SELECT facility.id, service.id, offer.price
FROM (VALUES
    ('Sample Padma Diagnostic Centre', 'Complete Blood Count (CBC)', 350),
    ('Sample Rajshahi General Hospital', 'Complete Blood Count (CBC)', 420),
    ('Sample North Bengal Medical Centre', 'Complete Blood Count (CBC)', 390),
    ('Sample Padma Diagnostic Centre', 'ECG (Electrocardiogram)', 500),
    ('Sample Rajshahi General Hospital', 'ECG (Electrocardiogram)', 600),
    ('Sample North Bengal Medical Centre', 'ECG (Electrocardiogram)', 550),
    ('Sample Padma Diagnostic Centre', 'X-Ray (Chest)', 600),
    ('Sample Rajshahi General Hospital', 'X-Ray (Chest)', 750),
    ('Sample North Bengal Medical Centre', 'X-Ray (Chest)', 680),
    ('Sample Padma Diagnostic Centre', 'Ultrasound (Abdomen)', 1200),
    ('Sample Rajshahi General Hospital', 'Ultrasound (Abdomen)', 1500),
    ('Sample North Bengal Medical Centre', 'Ultrasound (Abdomen)', 1350)
) AS offer(facility_name, service_name, price)
JOIN diagnostic_facilities facility ON facility.name = offer.facility_name
JOIN medical_services service ON service.name = offer.service_name
ON CONFLICT (facility_id, service_id) DO NOTHING;

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM doctors) THEN
        INSERT INTO doctors (name, specialty, location, consultation_fee, is_verified)
        VALUES
            ('Dr. Abdul Mannan', 'Cardiologist', 'Rajshahi', 1000, TRUE),
            ('Dr. Farhana Akter', 'Gynecologist', 'Rajshahi', 800, TRUE),
            ('Dr. Rafiqul Islam', 'Orthopedic Surgeon', 'Rajshahi', 1200, TRUE),
            ('Dr. Nasrin Sultana', 'Pediatrician', 'Rajshahi', 600, TRUE),
            ('Dr. Kamal Hossain', 'Neurologist', 'Rajshahi', 1500, FALSE),
            ('Dr. Shamsun Nahar', 'Dermatologist', 'Rajshahi', 700, TRUE),
            ('Dr. Mizanur Rahman', 'ENT Specialist', 'Rajshahi', 900, TRUE),
            ('Dr. Tahmina Begum', 'Ophthalmologist', 'Rajshahi', 850, TRUE),
            ('Dr. Jahangir Alam', 'General Physician', 'Rajshahi', 500, TRUE),
            ('Dr. Sabina Yasmin', 'Psychiatrist', 'Rajshahi', 1100, FALSE),
            ('Dr. Mahmud Hasan', 'Urologist', 'Rajshahi', 1300, TRUE),
            ('Dr. Ayesha Siddika', 'Endocrinologist', 'Rajshahi', 1000, TRUE);
    END IF;
END $$;

INSERT INTO doctor_schedules (doctor_id, day_of_week, start_time, end_time)
SELECT d.id, days.day_of_week, '09:00', '17:00'
FROM doctors AS d
CROSS JOIN (VALUES (1), (2), (3), (4), (7)) AS days(day_of_week)
ON CONFLICT (doctor_id, day_of_week) DO NOTHING;

INSERT INTO doctor_trust_profiles (doctor_id)
SELECT d.id
FROM doctors AS d
ON CONFLICT (doctor_id) DO NOTHING;
