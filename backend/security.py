import os
import secrets
from datetime import datetime, timedelta, timezone

import bcrypt
import jwt
import pyotp
from cryptography.fernet import Fernet


GENERIC_LOGIN = "Invalid email or password"
GENERIC_DOCTOR_LOGIN = "Invalid email or identifier"


def jwt_secret():
    return os.getenv("JWT_SECRET") or os.getenv("SECRET_KEY")


def require_production_secrets(app_mode: str):
    if app_mode.lower() == "production":
        jwt_secret_value = jwt_secret()
        fernet_key = os.getenv("FERNET_KEY")
        placeholders = {"", "replace_with_a_long_random_secret", "replace_with_a_valid_fernet_key"}
        if not jwt_secret_value or jwt_secret_value in placeholders:
            raise RuntimeError("JWT_SECRET must be configured in production")
        if not fernet_key or fernet_key in placeholders:
            raise RuntimeError("FERNET_KEY must be configured in production")


def create_token(user_id: int, role: str, token_version: int, minutes: int = 30):
    payload = {
        "user_id": user_id,
        "role": role,
        "token_version": token_version,
        "exp": datetime.now(timezone.utc) + timedelta(minutes=minutes),
    }
    return jwt.encode(payload, jwt_secret(), algorithm="HS256")


def decode_token(token: str):
    return jwt.decode(token, jwt_secret(), algorithms=["HS256"])


def encrypt_totp(secret: str) -> str:
    return Fernet(os.environ["FERNET_KEY"].encode()).encrypt(secret.encode()).decode()


def decrypt_totp(value: str) -> str:
    return Fernet(os.environ["FERNET_KEY"].encode()).decrypt(value.encode()).decode()


def new_totp_secret():
    return pyotp.random_base32()


def verify_totp(secret: str, code: str) -> bool:
    return pyotp.TOTP(secret).verify(str(code).strip(), valid_window=1)


def new_doctor_id():
    alphabet = "23456789ABCDEFGHJKMNPQRSTUVWXYZ"
    groups = ["".join(secrets.choice(alphabet) for _ in range(4)) for _ in range(3)]
    return "MGD-" + "-".join(groups)
