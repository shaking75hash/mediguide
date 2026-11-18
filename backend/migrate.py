import os
from pathlib import Path
import psycopg2
from dotenv import load_dotenv

load_dotenv()


def migrate(database_url=None):
    conn = psycopg2.connect(database_url or os.environ["DATABASE_URL"])
    migration_dir = Path(__file__).with_name("migrations")
    cur = conn.cursor()
    cur.execute(
        "CREATE TABLE IF NOT EXISTS schema_migrations "
        "(version VARCHAR(255) PRIMARY KEY, applied_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP)"
    )
    conn.commit()
    for path in sorted(migration_dir.glob("*.sql")):
        cur.execute("SELECT 1 FROM schema_migrations WHERE version = %s", (path.name,))
        if cur.fetchone():
            continue
        cur.execute(path.read_text(encoding="utf-8"))
        cur.execute("INSERT INTO schema_migrations (version) VALUES (%s)", (path.name,))
        conn.commit()
    cur.close()
    conn.close()


if __name__ == "__main__":
    migrate()
    print("Migrations complete")
