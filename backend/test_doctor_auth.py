import os
import unittest
from types import SimpleNamespace
from unittest.mock import Mock, patch

os.environ["RUN_MIGRATIONS_ON_START"] = "false"
os.environ.setdefault("JWT_SECRET", "test-secret-for-doctor-auth")

import bcrypt
from fastapi import HTTPException

from backend.main import (
    DoctorLogin,
    DoctorProfileUpdate,
    DoctorRegistration,
    doctor_login,
    get_doctor_profile,
    get_doctors,
    get_single_doctor,
    initialize_database,
    register_doctor,
    seed_demo_doctor_accounts,
    update_doctor_profile,
)


class DoctorAuthTests(unittest.TestCase):
    def setUp(self):
        self.request = SimpleNamespace(
            client=SimpleNamespace(host="127.0.0.1")
        )

    def test_demo_accounts_seed_even_when_startup_migrations_are_disabled(self):
        with (
            patch.dict(
                os.environ,
                {
                    "RUN_MIGRATIONS_ON_START": "false",
                    "APP_MODE": "demo",
                },
            ),
            patch("backend.main.migrate") as migrate,
            patch("backend.main.seed_demo_doctor_accounts") as seed_accounts,
        ):
            os.environ.pop("ENABLE_DEMO_DOCTOR_ACCOUNTS", None)
            initialize_database()

        migrate.assert_not_called()
        seed_accounts.assert_called_once()

    def test_render_test_service_seeds_despite_stale_flags(self):
        with (
            patch.dict(
                os.environ,
                {
                    "RUN_MIGRATIONS_ON_START": "false",
                    "APP_MODE": "production",
                    "ENABLE_DEMO_DOCTOR_ACCOUNTS": "false",
                    "RENDER_SERVICE_NAME": "mediguide-test-api",
                },
            ),
            patch("backend.main.migrate") as migrate,
            patch("backend.main.seed_demo_doctor_accounts") as seed_accounts,
        ):
            initialize_database()

        migrate.assert_not_called()
        seed_accounts.assert_called_once()

    def test_registration_creates_unverified_profile_and_doctor_user(self):
        cursor = Mock()
        cursor.fetchone.side_effect = [None, (42,), (17,)]
        connection = Mock()
        connection.cursor.return_value = cursor
        body = DoctorRegistration(
            name="Dr Example",
            specialty="Cardiologist",
            location="Rajshahi",
            qualification="MBBS, FCPS",
            consultation_fee=850,
            email="doctor@example.com",
            password="secure-pass-123",
        )

        with (
            patch("backend.main.get_db_connection", return_value=connection),
            patch("backend.main.is_rate_limited", return_value=False),
            patch("backend.main.clear_rate_limit"),
            patch("backend.main.create_token", return_value="doctor-token"),
        ):
            result = register_doctor(body, self.request)

        self.assertEqual(result["access_token"], "doctor-token")
        self.assertEqual(result["doctor_id"], 42)
        self.assertEqual(result["role"], "doctor")
        self.assertEqual(cursor.execute.call_count, 3)
        doctor_query, doctor_params = cursor.execute.call_args_list[1].args
        self.assertIn("is_verified)", doctor_query)
        self.assertIn("FALSE", doctor_query)
        self.assertEqual(
            doctor_params,
            ("Dr Example", "Cardiology", "Rajshahi", 850, "MBBS, FCPS"),
        )
        user_query, user_params = cursor.execute.call_args_list[2].args
        self.assertIn("'doctor'", user_query)
        self.assertEqual(user_params[:2], ("Dr Example", "doctor@example.com"))
        self.assertTrue(
            bcrypt.checkpw("secure-pass-123".encode(), user_params[2].encode())
        )
        self.assertEqual(user_params[3], 42)
        connection.commit.assert_called_once()

    def test_registration_rejects_duplicate_email_without_creating_profile(self):
        cursor = Mock()
        cursor.fetchone.return_value = (1,)
        connection = Mock()
        connection.cursor.return_value = cursor
        body = DoctorRegistration(
            name="Dr Example",
            specialty="Cardiology",
            location="Rajshahi",
            consultation_fee=850,
            email="doctor@example.com",
            password="secure-pass-123",
        )

        with (
            patch("backend.main.get_db_connection", return_value=connection),
            patch("backend.main.is_rate_limited", return_value=False),
            self.assertRaises(HTTPException) as raised,
        ):
            register_doctor(body, self.request)

        self.assertEqual(raised.exception.status_code, 409)
        self.assertEqual(cursor.execute.call_count, 1)
        connection.rollback.assert_called_once()
        connection.commit.assert_not_called()

    def test_registration_rejects_unknown_specialty(self):
        body = DoctorRegistration(
            name="Dr Example",
            specialty="Imaginary Medicine",
            location="Rajshahi",
            consultation_fee=850,
            email="doctor@example.com",
            password="secure-pass-123",
        )

        with (
            patch("backend.main.is_rate_limited", return_value=False),
            patch("backend.main.get_db_connection") as get_connection,
            self.assertRaises(HTTPException) as raised,
        ):
            register_doctor(body, self.request)

        self.assertEqual(raised.exception.status_code, 422)
        get_connection.assert_not_called()

    def test_registration_rejects_passwords_beyond_bcrypt_limit(self):
        body = DoctorRegistration(
            name="Dr Example",
            specialty="Cardiology",
            location="Rajshahi",
            consultation_fee=850,
            email="doctor@example.com",
            password="é" * 40,
        )

        with (
            patch("backend.main.is_rate_limited", return_value=False),
            patch("backend.main.get_db_connection") as get_connection,
            self.assertRaises(HTTPException) as raised,
        ):
            register_doctor(body, self.request)

        self.assertEqual(raised.exception.status_code, 422)
        get_connection.assert_not_called()

    def test_doctor_sign_in_uses_email_and_password(self):
        password_hash = bcrypt.hashpw(
            "secure-pass-123".encode(), bcrypt.gensalt()
        ).decode()
        cursor = Mock()
        cursor.fetchone.return_value = (17, password_hash, 1, False)
        connection = Mock()
        connection.cursor.return_value = cursor
        body = DoctorLogin(email="doctor@example.com", password="secure-pass-123")

        with (
            patch("backend.main.get_db_connection", return_value=connection),
            patch("backend.main.is_rate_limited", return_value=False),
            patch("backend.main.clear_rate_limit"),
            patch("backend.main.create_token", return_value="doctor-token"),
        ):
            result = doctor_login(body, self.request)

        self.assertEqual(result["access_token"], "doctor-token")
        self.assertEqual(result["role"], "doctor")
        query = cursor.execute.call_args_list[0].args[0]
        self.assertIn("lower(u.email)", query)
        self.assertIn("u.role = 'doctor'", query)
        connection.commit.assert_called_once()

    def test_doctor_sign_in_rejects_wrong_password(self):
        password_hash = bcrypt.hashpw(
            "secure-pass-123".encode(), bcrypt.gensalt()
        ).decode()
        cursor = Mock()
        cursor.fetchone.return_value = (17, password_hash, 1, False)
        connection = Mock()
        connection.cursor.return_value = cursor
        body = DoctorLogin(email="doctor@example.com", password="wrong-password")

        with (
            patch("backend.main.get_db_connection", return_value=connection),
            patch("backend.main.is_rate_limited", return_value=False),
            self.assertRaises(HTTPException) as raised,
        ):
            doctor_login(body, self.request)

        self.assertEqual(raised.exception.status_code, 401)
        connection.commit.assert_not_called()

    def test_doctor_profile_returns_current_location_and_qualification(self):
        cursor = Mock()
        cursor.fetchone.return_value = (
            42,
            "Dr Example",
            "Cardiology",
            "Rajshahi",
            850,
            False,
            "MBBS, FCPS",
            True,
            "doctor@example.com",
        )
        connection = Mock()
        connection.cursor.return_value = cursor

        with patch("backend.main.get_db_connection", return_value=connection):
            profile = get_doctor_profile({"doctor_id": 42, "id": 17})

        self.assertEqual(profile["location"], "Rajshahi")
        self.assertEqual(profile["qualification"], "MBBS, FCPS")
        self.assertTrue(profile["is_sample"])
        self.assertEqual(profile["email"], "doctor@example.com")

    def test_doctor_can_update_location_and_qualification(self):
        cursor = Mock()
        cursor.fetchone.return_value = (
            42,
            "Dr Example",
            "Cardiology",
            "Dhaka",
            850,
            False,
            "MBBS, MD",
            True,
            "doctor@example.com",
        )
        connection = Mock()
        connection.cursor.return_value = cursor
        body = DoctorProfileUpdate(
            location="  Dhaka  ",
            qualification="  MBBS, MD  ",
        )

        with patch("backend.main.get_db_connection", return_value=connection):
            profile = update_doctor_profile(
                body,
                {"doctor_id": 42, "id": 17},
            )

        self.assertEqual(profile["location"], "Dhaka")
        self.assertEqual(profile["qualification"], "MBBS, MD")
        self.assertTrue(profile["is_sample"])
        self.assertEqual(
            cursor.execute.call_args.args[1],
            ("Dhaka", "MBBS, MD", 42, 17),
        )
        connection.commit.assert_called_once()

    def test_doctor_directory_includes_qualification(self):
        cursor = Mock()
        cursor.fetchall.return_value = [
            (42, "Dr Example", "Cardiology", "Rajshahi", 850, False, "MBBS", True)
        ]
        connection = Mock()
        connection.cursor.return_value = cursor

        with patch("backend.main.get_db_connection", return_value=connection):
            profiles = get_doctors()

        self.assertEqual(profiles[0]["qualification"], "MBBS")
        self.assertTrue(profiles[0]["is_sample"])
        self.assertIn("qualification", cursor.execute.call_args.args[0])

    def test_single_doctor_returns_sample_label(self):
        cursor = Mock()
        cursor.fetchone.return_value = (
            42,
            "Dr Example",
            "Cardiology",
            "Rajshahi",
            850,
            False,
            "Demo-only sample profile",
            True,
        )
        connection = Mock()
        connection.cursor.return_value = cursor

        with patch("backend.main.get_db_connection", return_value=connection):
            profile = get_single_doctor(42)

        self.assertTrue(profile["is_sample"])

    def test_demo_seed_creates_synthetic_doctor_login(self):
        cursor = Mock()
        cursor.fetchall.return_value = [(42, "Dr. Example")]
        cursor.fetchone.side_effect = [None, None]
        connection = Mock()
        connection.cursor.return_value = cursor

        with (
            patch.dict(
                os.environ,
                {
                    "APP_MODE": "demo",
                    "DEMO_DOCTOR_PASSWORD": "MediGuideDemo123!",
                },
            ),
            patch("backend.main.get_db_connection", return_value=connection),
        ):
            seed_demo_doctor_accounts()

        insert_query, insert_params = cursor.execute.call_args_list[3].args
        self.assertIn("INSERT INTO users", insert_query)
        self.assertEqual(insert_params[:2], ("Dr. Example", "dr-example@example.com"))
        self.assertTrue(
            bcrypt.checkpw(
                "MediGuideDemo123!".encode(),
                insert_params[2].encode(),
            )
        )
        self.assertEqual(insert_params[3], 42)
        connection.commit.assert_called_once()

    def test_demo_seed_uses_the_documented_password_when_unconfigured(self):
        cursor = Mock()
        cursor.fetchall.return_value = [(42, "Dr. Example")]
        cursor.fetchone.side_effect = [None, None]
        connection = Mock()
        connection.cursor.return_value = cursor

        with (
            patch.dict(os.environ, {"APP_MODE": "demo"}, clear=False),
            patch("backend.main.get_db_connection", return_value=connection),
        ):
            os.environ.pop("DEMO_DOCTOR_PASSWORD", None)
            seed_demo_doctor_accounts()

        _, insert_params = cursor.execute.call_args_list[3].args
        self.assertTrue(
            bcrypt.checkpw(
                b"MediGuideDemo123!",
                insert_params[2].encode(),
            )
        )
        connection.commit.assert_called_once()

    def test_demo_seed_is_allowed_on_the_named_render_test_service(self):
        cursor = Mock()
        cursor.fetchall.return_value = [(42, "Dr. Example")]
        cursor.fetchone.side_effect = [None, None]
        connection = Mock()
        connection.cursor.return_value = cursor

        with (
            patch.dict(
                os.environ,
                {
                    "APP_MODE": "production",
                    "RENDER_SERVICE_NAME": "mediguide-test-api",
                    "DEMO_DOCTOR_PASSWORD": "MediGuideDemo123!",
                },
            ),
            patch("backend.main.get_db_connection", return_value=connection),
        ):
            seed_demo_doctor_accounts()

        connection.commit.assert_called_once()

    def test_demo_seed_updates_existing_synthetic_account_password(self):
        cursor = Mock()
        cursor.fetchall.return_value = [(42, "Dr. Example")]
        cursor.fetchone.return_value = (19, "dr-example@example.com")
        connection = Mock()
        connection.cursor.return_value = cursor

        with (
            patch.dict(
                os.environ,
                {
                    "APP_MODE": "demo",
                    "DEMO_DOCTOR_PASSWORD": "UpdatedDemo123!",
                },
            ),
            patch("backend.main.get_db_connection", return_value=connection),
        ):
            seed_demo_doctor_accounts()

        update_query, update_params = cursor.execute.call_args.args
        self.assertIn("UPDATE users SET password_hash", update_query)
        self.assertTrue(
            bcrypt.checkpw(
                "UpdatedDemo123!".encode(),
                update_params[0].encode(),
            )
        )
        self.assertEqual(update_params[1], 19)
        connection.commit.assert_called_once()

    def test_demo_seed_adds_generated_login_when_sample_has_another_account(self):
        cursor = Mock()
        cursor.fetchall.return_value = [(42, "Dr. Example")]
        cursor.fetchone.side_effect = [(19, "doctor@real.test"), None]
        connection = Mock()
        connection.cursor.return_value = cursor

        with (
            patch.dict(
                os.environ,
                {
                    "APP_MODE": "demo",
                    "DEMO_DOCTOR_PASSWORD": "MediGuideDemo123!",
                },
            ),
            patch("backend.main.get_db_connection", return_value=connection),
        ):
            seed_demo_doctor_accounts()

        insert_query, insert_params = cursor.execute.call_args_list[3].args
        self.assertIn("INSERT INTO users", insert_query)
        self.assertEqual(insert_params[:2], ("Dr. Example", "dr-example@example.com"))
        self.assertEqual(insert_params[3], 42)
        connection.commit.assert_called_once()

    def test_demo_seed_refuses_a_non_demo_app_mode(self):
        with (
            patch.dict(
                os.environ,
                {
                    "APP_MODE": "production",
                    "DEMO_DOCTOR_PASSWORD": "MediGuideDemo123!",
                },
            ),
            patch("backend.main.get_db_connection") as get_connection,
            self.assertRaises(RuntimeError),
        ):
            seed_demo_doctor_accounts()

        get_connection.assert_not_called()

    def test_blank_location_cannot_be_saved(self):
        body = DoctorProfileUpdate(location="   ", qualification="MBBS")

        with (
            patch("backend.main.get_db_connection") as get_connection,
            self.assertRaises(HTTPException) as raised,
        ):
            update_doctor_profile(body, {"doctor_id": 42, "id": 17})

        self.assertEqual(raised.exception.status_code, 422)
        get_connection.assert_not_called()


if __name__ == "__main__":
    unittest.main()
