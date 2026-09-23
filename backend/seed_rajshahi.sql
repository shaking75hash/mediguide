-- Clear existing sample data to avoid duplicates if you run this twice
DELETE FROM doctor_schedules;
DELETE FROM doctors;

-- Insert Rajshahi-based Doctors
INSERT INTO doctors (name, specialty, location, consultation_fee, is_verified) VALUES
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

-- Assign Schedules (Mon-Thu and Sun) for all new doctors
-- Day 1=Mon, 2=Tue, 3=Wed, 4=Thu, 7=Sun
INSERT INTO doctor_schedules (doctor_id, day_of_week, start_time, end_time)
SELECT d.id, dow.day, '09:00', '17:00'
FROM doctors d
CROSS JOIN (VALUES (1),(2),(3),(4),(7)) AS dow(day)
WHERE NOT EXISTS (
    SELECT 1 FROM doctor_schedules ds
    WHERE ds.doctor_id = d.id AND ds.day_of_week = dow.day
);
