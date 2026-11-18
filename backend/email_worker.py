import os
import smtplib
import time
from email.message import EmailMessage

from .database import get_db_connection


def send_pending(limit=20):
    conn = get_db_connection()
    cur = conn.cursor()
    cur.execute(
        "SELECT id, recipient, subject, body, attempts FROM email_outbox "
        "WHERE status = 'pending' AND attempts < 5 ORDER BY id ASC LIMIT %s;",
        (limit,),
    )
    rows = cur.fetchall()
    cur.close()
    conn.close()

    for row in rows:
        message = EmailMessage()
        message["From"] = os.environ["MAIL_FROM"]
        message["To"] = row[1]
        message["Subject"] = row[2]
        message.set_content(row[3])
        try:
            with smtplib.SMTP(os.environ["SMTP_HOST"], int(os.getenv("SMTP_PORT", "1025"))) as smtp:
                if os.getenv("SMTP_USER"):
                    smtp.login(os.environ["SMTP_USER"], os.getenv("SMTP_PASSWORD", ""))
                smtp.send_message(message)
            conn = get_db_connection()
            cur = conn.cursor()
            cur.execute(
                "UPDATE email_outbox SET status = 'sent', attempts = attempts + 1, sent_at = CURRENT_TIMESTAMP WHERE id = %s;",
                (row[0],),
            )
            conn.commit()
            cur.close()
            conn.close()
        except Exception:
            conn = get_db_connection()
            cur = conn.cursor()
            cur.execute(
                "UPDATE email_outbox SET attempts = attempts + 1, status = CASE WHEN attempts + 1 >= 5 THEN 'failed' ELSE 'pending' END WHERE id = %s;",
                (row[0],),
            )
            conn.commit()
            cur.close()
            conn.close()


if __name__ == "__main__":
    interval = int(os.getenv("EMAIL_WORKER_INTERVAL", "10"))
    while True:
        send_pending()
        time.sleep(interval)
