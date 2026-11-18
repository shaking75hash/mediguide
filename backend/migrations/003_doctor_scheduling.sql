ALTER TABLE doctor_schedules
    ADD COLUMN IF NOT EXISTS session_length_minutes INTEGER NOT NULL DEFAULT 30;

DO $$ BEGIN
    ALTER TABLE doctor_schedules ADD CONSTRAINT doctor_schedules_session_check
        CHECK (
            session_length_minutes BETWEEN 5 AND 60
            AND session_length_minutes % 5 = 0
        );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

CREATE TABLE IF NOT EXISTS doctor_days_off (
    id SERIAL PRIMARY KEY,
    doctor_id INTEGER NOT NULL REFERENCES doctors(id) ON DELETE CASCADE,
    off_date DATE NOT NULL,
    reason TEXT,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE (doctor_id, off_date)
);

CREATE TABLE IF NOT EXISTS doctor_audit_log (
    id SERIAL PRIMARY KEY,
    doctor_id INTEGER NOT NULL REFERENCES doctors(id),
    action VARCHAR(100) NOT NULL,
    affected_type VARCHAR(100),
    affected_id VARCHAR(100),
    previous_value TEXT,
    new_value TEXT,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);
