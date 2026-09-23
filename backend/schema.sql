-- Users Table
CREATE TABLE IF NOT EXISTS users (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    password_hash TEXT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

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

-- Insert some sample data so the app isn't empty
INSERT INTO doctors (name, specialty, location, consultation_fee, is_verified) VALUES 
('Dr. Rahman', 'Cardiologist', 'Rajshahi', 800.00, TRUE),
('Dr. Karim', 'Neurologist', 'Dhaka', 1000.00, TRUE),
('Dr. Ahmed', 'Dermatologist', 'Chittagong', 600.00, FALSE);

-- Sample schedule for Dr. Rahman (Mondays 9 AM to 5 PM)
INSERT INTO doctor_schedules (doctor_id, day_of_week, start_time, end_time) VALUES 
(1, 1, '09:00:00', '17:00:00');