import datetime
import os
import unittest
from unittest.mock import Mock, patch

os.environ["RUN_MIGRATIONS_ON_START"] = "false"
os.environ.setdefault("JWT_SECRET", "test-secret-for-appointment-expiry")

from backend.main import expire_overdue_appointments, validate_slot


class AppointmentExpiryTests(unittest.TestCase):
    def test_slot_validation_returns_the_configured_session_length(self):
        cursor = Mock()
        cursor.fetchone.side_effect = [None, None]
        cursor.fetchall.return_value = [
            (datetime.time(9, 0), datetime.time(12, 0), 45)
        ]
        appointment_date = datetime.date.today() + datetime.timedelta(days=7)

        session_minutes = validate_slot(
            cursor, 12, 0, appointment_date, datetime.time(9, 0)
        )

        self.assertEqual(session_minutes, 45)

    def test_expiry_uses_local_timezone_and_session_duration(self):
        cursor = Mock()
        cursor.rowcount = 2
        connection = Mock()
        connection.cursor.return_value = cursor

        with (
            patch.dict(os.environ, {"APPOINTMENT_TIMEZONE": "Asia/Dhaka"}),
            patch("backend.main.get_db_connection", return_value=connection),
        ):
            expired_count = expire_overdue_appointments()

        self.assertEqual(expired_count, 2)
        query, parameters = cursor.execute.call_args.args
        self.assertIn("SET status = 'missed'", query)
        self.assertIn("session_length_minutes", query)
        self.assertIn("status IN ('scheduled', 'rescheduled')", query)
        self.assertIn("CURRENT_TIMESTAMP AT TIME ZONE %s", query)
        self.assertEqual(parameters, ("Asia/Dhaka",))
        connection.commit.assert_called_once()
        connection.close.assert_called_once()

    def test_expiry_rolls_back_and_closes_connection_on_database_error(self):
        cursor = Mock()
        cursor.execute.side_effect = RuntimeError("database unavailable")
        connection = Mock()
        connection.cursor.return_value = cursor

        with (
            patch("backend.main.get_db_connection", return_value=connection),
            self.assertRaisesRegex(RuntimeError, "database unavailable"),
        ):
            expire_overdue_appointments()

        connection.rollback.assert_called_once()
        connection.close.assert_called_once()


if __name__ == "__main__":
    unittest.main()
