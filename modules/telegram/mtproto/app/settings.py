import os
from dataclasses import dataclass


@dataclass(frozen=True)
class Settings:
    client_token: str
    database_url: str
    session_encryption_key: str

    @classmethod
    def from_environment(cls) -> "Settings":
        return cls(
            client_token=os.environ.get("TELEGRAM_MTPROTO_CLIENT_TOKEN", ""),
            database_url=os.environ.get("TELEGRAM_MTPROTO_DATABASE_URL", ""),
            session_encryption_key=os.environ.get(
                "TELEGRAM_MTPROTO_SESSION_ENCRYPTION_KEY", ""
            ),
        )

