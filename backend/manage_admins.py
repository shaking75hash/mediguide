import getpass
import os

import bcrypt
import pyotp

from .database import get_db_connection
from .security import encrypt_totp


def main():
    if not os.getenv("DATABASE_URL", "").strip():
        raise SystemExit(
            "DATABASE_URL must be set explicitly to the database where the "
            "administrator should be created."
        )

    email = (os.getenv("ADMIN_EMAIL") or input("Administrator email: ")).strip().lower()
    password = os.getenv("ADMIN_PASSWORD")
    if password is None:
        password = getpass.getpass("Administrator password: ")
        confirmation = getpass.getpass("Confirm password: ")
    else:
        confirmation = password
    if password != confirmation:
        raise SystemExit("Passwords do not match")
    secret = pyotp.random_base32()
    password_hash = bcrypt.hashpw(password.encode(), bcrypt.gensalt()).decode()
    conn = get_db_connection()
    cur = conn.cursor()
    cur.execute(
        """INSERT INTO users (name, email, password_hash, role, token_version, totp_secret_encrypted, totp_enabled)
           VALUES ('Administrator', %s, %s, 'admin', 1, %s, TRUE)
           ON CONFLICT (email) DO UPDATE SET role = 'admin',
               password_hash = EXCLUDED.password_hash,
               token_version = users.token_version + 1,
               totp_secret_encrypted = EXCLUDED.totp_secret_encrypted,
               totp_enabled = TRUE,
               doctor_id = NULL,
               disabled = FALSE
           RETURNING id;""",
        (email, password_hash, encrypt_totp(secret)),
    )
    cur.fetchone()
    conn.commit()
    cur.close()
    conn.close()
    print("Administrator created")
    print(f"TOTP secret: {secret}")
    print(pyotp.TOTP(secret).provisioning_uri(name=email, issuer_name="MediGuide"))


if __name__ == "__main__":
    main()
