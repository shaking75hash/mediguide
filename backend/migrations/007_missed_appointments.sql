ALTER TABLE appointments
    ADD COLUMN IF NOT EXISTS session_length_minutes INTEGER NOT NULL DEFAULT 30;

UPDATE appointments a
SET session_length_minutes = s.session_length_minutes
FROM doctor_schedules s
WHERE s.doctor_id = a.doctor_id
  AND s.day_of_week = EXTRACT(ISODOW FROM a.appointment_date)::INTEGER
  AND a.appointment_time >= s.start_time
  AND a.appointment_time + make_interval(mins => s.session_length_minutes) <= s.end_time
  AND MOD(
      EXTRACT(EPOCH FROM (a.appointment_time - s.start_time))::INTEGER,
      s.session_length_minutes * 60
  ) = 0;

ALTER TABLE appointments DROP CONSTRAINT IF EXISTS appointments_status_check;
ALTER TABLE appointments ADD CONSTRAINT appointments_status_check CHECK (
    status IN ('scheduled', 'rescheduled', 'cancelled', 'cancelled_by_doctor', 'missed')
);
