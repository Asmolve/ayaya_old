from __future__ import annotations

import hashlib
import hmac
import base64
from dataclasses import dataclass

from cryptography.fernet import Fernet


SCHEMA = """
CREATE TABLE IF NOT EXISTS telegram_mtproto_sessions (
    id BIGSERIAL PRIMARY KEY,
    account_id TEXT NOT NULL UNIQUE,
    handle_digest BYTEA NOT NULL UNIQUE,
    encrypted_session BYTEA NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
)
"""


@dataclass(frozen=True)
class StoredSession:
    account_id: str
    session: str


class SessionStorage:
    def __init__(self, database_url: str, encryption_key: str):
        self.database_url = database_url
        self._handle_key = base64.urlsafe_b64decode(encryption_key.encode("ascii"))
        self._fernet = Fernet(encryption_key.encode("ascii"))

    def _connect(self):
        import psycopg

        return psycopg.connect(self.database_url)

    def migrate(self) -> None:
        with self._connect() as connection:
            with connection.cursor() as cursor:
                cursor.execute(SCHEMA)

    def ready(self) -> bool:
        try:
            with self._connect() as connection:
                with connection.cursor() as cursor:
                    cursor.execute("SELECT 1")
                    return cursor.fetchone() == (1,)
        except Exception:
            return False

    def _digest(self, handle: str) -> bytes:
        return hmac.new(self._handle_key, handle.encode("utf-8"), hashlib.sha256).digest()

    def save(self, account_id: str, handle: str, session: str) -> None:
        digest = self._digest(handle)
        encrypted = self._fernet.encrypt(session.encode("utf-8"))
        with self._connect() as connection:
            with connection.cursor() as cursor:
                cursor.execute(
                    """
                    INSERT INTO telegram_mtproto_sessions
                        (account_id, handle_digest, encrypted_session)
                    VALUES (%s, %s, %s)
                    ON CONFLICT (account_id) DO UPDATE SET
                        handle_digest = EXCLUDED.handle_digest,
                        encrypted_session = EXCLUDED.encrypted_session,
                        updated_at = CURRENT_TIMESTAMP
                    """,
                    (account_id, digest, encrypted),
                )

    def fetch(self, account_id: str, handle: str) -> StoredSession | None:
        digest = self._digest(handle)
        with self._connect() as connection:
            with connection.cursor() as cursor:
                cursor.execute(
                    """
                    SELECT account_id, encrypted_session
                    FROM telegram_mtproto_sessions
                    WHERE account_id = %s AND handle_digest = %s
                    """,
                    (account_id, digest),
                )
                row = cursor.fetchone()
        if row is None:
            return None
        return StoredSession(row[0], self._fernet.decrypt(bytes(row[1])).decode("utf-8"))

    def delete(self, account_id: str, handle: str) -> None:
        with self._connect() as connection:
            with connection.cursor() as cursor:
                cursor.execute(
                    "DELETE FROM telegram_mtproto_sessions WHERE account_id = %s AND handle_digest = %s",
                    (account_id, self._digest(handle)),
                )


def new_fernet_key() -> str:
    return Fernet.generate_key().decode("ascii")
