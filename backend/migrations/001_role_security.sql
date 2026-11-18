ALTER TABLE users ADD COLUMN IF NOT EXISTS role VARCHAR(20) NOT NULL DEFAULT 'patient';
ALTER TABLE users ADD COLUMN IF NOT EXISTS doctor_id INTEGER;
ALTER TABLE users ADD COLUMN IF NOT EXISTS token_version INTEGER NOT NULL DEFAULT 1;
ALTER TABLE users ADD COLUMN IF NOT EXISTS totp_secret_encrypted TEXT;
ALTER TABLE users ADD COLUMN IF NOT EXISTS totp_enabled BOOLEAN NOT NULL DEFAULT FALSE;
ALTER TABLE users ADD COLUMN IF NOT EXISTS last_login_at TIMESTAMP WITH TIME ZONE;
ALTER TABLE users ADD COLUMN IF NOT EXISTS disabled BOOLEAN NOT NULL DEFAULT FALSE;

DO $$ BEGIN
    ALTER TABLE users ADD CONSTRAINT users_role_check CHECK (role IN ('patient', 'doctor', 'admin'));
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;
DO $$ BEGIN
    ALTER TABLE users ADD CONSTRAINT users_doctor_role_check CHECK (
        (role = 'doctor' AND doctor_id IS NOT NULL)
        OR (role <> 'doctor' AND doctor_id IS NULL)
    );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;
DO $$ BEGIN
    ALTER TABLE users ADD CONSTRAINT users_doctor_id_fkey FOREIGN KEY (doctor_id) REFERENCES doctors(id);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

ALTER TABLE doctors ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMP WITH TIME ZONE;
ALTER TABLE doctors ADD COLUMN IF NOT EXISTS is_sample BOOLEAN NOT NULL DEFAULT FALSE;
ALTER TABLE doctors ADD COLUMN IF NOT EXISTS approved_request_id INTEGER;

ALTER TABLE appointments ADD COLUMN IF NOT EXISTS rescheduled_from_date DATE;
ALTER TABLE appointments ADD COLUMN IF NOT EXISTS rescheduled_from_time TIME;
UPDATE appointments SET status = 'cancelled' WHERE status = 'completed';
UPDATE appointments SET status = 'scheduled' WHERE status = 'confirmed';
UPDATE appointments SET status = 'scheduled' WHERE status IS NULL;
ALTER TABLE appointments DROP CONSTRAINT IF EXISTS appointments_status_check;
ALTER TABLE appointments ADD CONSTRAINT appointments_status_check CHECK (
    status IN ('scheduled', 'rescheduled', 'cancelled', 'cancelled_by_doctor')
);
DO $$ BEGIN
    ALTER TABLE appointments ADD CONSTRAINT appointments_doctor_slot_unique UNIQUE (doctor_id, appointment_date, appointment_time);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

CREATE TABLE IF NOT EXISTS doctor_requests (
    id SERIAL PRIMARY KEY,
    full_name VARCHAR(100) NOT NULL,
    specialty VARCHAR(100) NOT NULL,
    qualification TEXT NOT NULL,
    email VARCHAR(255) NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected')),
    reviewer_id INTEGER REFERENCES users(id),
    reviewed_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS doctor_credentials (
    id SERIAL PRIMARY KEY,
    request_id INTEGER NOT NULL REFERENCES doctor_requests(id),
    email VARCHAR(255) NOT NULL,
    identifier_hash TEXT NOT NULL,
    expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
    used_at TIMESTAMP WITH TIME ZONE,
    revoked_at TIMESTAMP WITH TIME ZONE
);

CREATE TABLE IF NOT EXISTS email_verifications (
    id SERIAL PRIMARY KEY,
    email VARCHAR(255) NOT NULL,
    code_hash TEXT NOT NULL,
    expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
    attempt_count INTEGER NOT NULL DEFAULT 0,
    used_at TIMESTAMP WITH TIME ZONE
);

CREATE TABLE IF NOT EXISTS admin_invites (
    id SERIAL PRIMARY KEY,
    token_hash VARCHAR(64) UNIQUE NOT NULL,
    email VARCHAR(255) NOT NULL,
    created_by INTEGER REFERENCES users(id),
    expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
    used_at TIMESTAMP WITH TIME ZONE
);

CREATE TABLE IF NOT EXISTS admin_audit_log (
    id SERIAL PRIMARY KEY,
    administrator_id INTEGER REFERENCES users(id),
    action VARCHAR(100) NOT NULL,
    target_type VARCHAR(100),
    target_id VARCHAR(100),
    ip_address VARCHAR(45),
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS notifications (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    message TEXT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    read_at TIMESTAMP WITH TIME ZONE
);

CREATE TABLE IF NOT EXISTS email_outbox (
    id SERIAL PRIMARY KEY,
    recipient VARCHAR(255) NOT NULL,
    subject VARCHAR(255) NOT NULL,
    body TEXT NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'pending',
    attempts INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    sent_at TIMESTAMP WITH TIME ZONE
);
