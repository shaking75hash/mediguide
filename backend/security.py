import os
from datetime import datetime, timedelta, timezone

import jwt


GENERIC_LOGIN = "Invalid email or password"
GENERIC_DOCTOR_LOGIN = "Invalid email or password"


def jwt_secret():
    return os.getenv("JWT_SECRET") or os.getenv("SECRET_KEY")


def require_production_secrets(app_mode: str):
    if app_mode.lower() == "production":
        jwt_secret_value = jwt_secret()
        placeholders = {"", "replace_with_a_long_random_secret"}
        if not jwt_secret_value or jwt_secret_value in placeholders:
            raise RuntimeError("JWT_SECRET must be configured in production")


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
