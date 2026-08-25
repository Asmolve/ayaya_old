from dataclasses import dataclass
from datetime import datetime, timezone
from typing import Any


@dataclass
class Challenge:
    account_id: str
    client: Any
    kind: str
    phone: str | None = None
    phone_code_hash: str | None = None
    qr_login: Any = None
    created_at: datetime = datetime.now(timezone.utc)


class ChallengeRegistry:
    def __init__(self):
        self._items: dict[str, Challenge] = {}

    def put(self, challenge_id: str, challenge: Challenge) -> None:
        self._items[challenge_id] = challenge

    def get(self, challenge_id: str) -> Challenge:
        try:
            return self._items[challenge_id]
        except KeyError as error:
            raise ValueError("authentication challenge is unavailable") from error

    def pop(self, challenge_id: str) -> Challenge:
        return self._items.pop(challenge_id)

