ALTER TABLE appointments DROP CONSTRAINT IF EXISTS appointments_doctor_slot_unique;
DROP INDEX IF EXISTS appointments_doctor_slot_unique;

CREATE UNIQUE INDEX IF NOT EXISTS appointments_active_slot_unique
ON appointments (doctor_id, appointment_date, appointment_time)
WHERE status IN ('scheduled', 'rescheduled');

CREATE UNIQUE INDEX IF NOT EXISTS doctor_credentials_active_email_unique
ON doctor_credentials (email)
WHERE revoked_at IS NULL;
