-- Users Table
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

-- Doctors Table
CREATE TABLE IF NOT EXISTS doctors (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    specialty VARCHAR(100),
    location VARCHAR(100),
    consultation_fee DECIMAL(10, 2),
    is_verified BOOLEAN DEFAULT FALSE
);

-- Doctor Schedules (for appointment slots)
CREATE TABLE IF NOT EXISTS doctor_schedules (
    id SERIAL PRIMARY KEY,
    doctor_id INT REFERENCES doctors(id) ON DELETE CASCADE,
    day_of_week INT NOT NULL CHECK (day_of_week BETWEEN 1 AND 7), -- 1=Mon, 7=Sun
    start_time TIME NOT NULL,
    end_time TIME NOT NULL
);

-- Appointments Table
CREATE TABLE IF NOT EXISTS appointments (
    id SERIAL PRIMARY KEY,
    patient_id INT REFERENCES users(id) ON DELETE CASCADE,
    doctor_id INT REFERENCES doctors(id) ON DELETE CASCADE,
    appointment_date DATE NOT NULL,
    appointment_time TIME NOT NULL,
    status VARCHAR(20) DEFAULT 'scheduled', -- scheduled, completed, cancelled
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

ALTER TABLE appointments ADD COLUMN IF NOT EXISTS doctor_advice TEXT;
ALTER TABLE appointments ADD COLUMN IF NOT EXISTS revisit_date DATE;
ALTER TABLE appointments ADD COLUMN IF NOT EXISTS revisit_notes TEXT;

CREATE TABLE IF NOT EXISTS medical_services (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    category VARCHAR(100),
    description TEXT
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

-- Insert some sample data so the app isn't empty
INSERT INTO doctors (name, specialty, location, consultation_fee, is_verified) VALUES 
('Dr. Rahman', 'Cardiologist', 'Rajshahi', 800.00, TRUE),
('Dr. Karim', 'Neurologist', 'Dhaka', 1000.00, TRUE),
('Dr. Ahmed', 'Dermatologist', 'Chittagong', 600.00, FALSE);

-- Sample schedule for Dr. Rahman (Mondays 9 AM to 5 PM)
INSERT INTO doctor_schedules (doctor_id, day_of_week, start_time, end_time) VALUES 
(1, 1, '09:00:00', '17:00:00');