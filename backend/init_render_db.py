from pathlib import Path

from backend.database import get_db_connection


def main() -> None:
    schema_path = Path(__file__).with_name("render_schema.sql")
    schema = schema_path.read_text(encoding="utf-8")
    connection = get_db_connection()
    try:
        with connection:
            with connection.cursor() as cursor:
                cursor.execute(schema)
    finally:
        connection.close()


if __name__ == "__main__":
    main()
