DROP TABLE IF EXISTS admin_audit_log;
DROP TABLE IF EXISTS admin_invites;

UPDATE doctor_requests
SET reviewer_id = NULL
WHERE reviewer_id IN (SELECT id FROM users WHERE role = 'admin');

DELETE FROM users WHERE role = 'admin';

ALTER TABLE users DROP CONSTRAINT IF EXISTS users_role_check;
ALTER TABLE users
    ADD CONSTRAINT users_role_check CHECK (role IN ('patient', 'doctor'));
ALTER TABLE users DROP COLUMN IF EXISTS totp_secret_encrypted;
ALTER TABLE users DROP COLUMN IF EXISTS totp_enabled;
