from fastapi.testclient import TestClient

from app.main import create_app
from app.storage import StoredSession


class Storage:
    def __init__(self):
        self.items = {}

    def ready(self):
        return True

    def save(self, account_id, handle, session):
        self.items[(account_id, handle)] = StoredSession(account_id, session)

    def fetch(self, account_id, handle):
        return self.items.get((account_id, handle))

    def delete(self, account_id, handle):
        self.items.pop((account_id, handle), None)


class Gateway:
    def start_phone(self, phone, api_id, api_hash):
        return "client", "phone-hash"

    def submit_code(self, client, phone, phone_code_hash, code):
        return {"state": "authenticated", "telegram_account_id": "42", "display_name": "Test User"}, "telethon-session"

    def submit_password(self, client, password):
        raise AssertionError("password path is not used by this test")

    def start_qr(self, api_id, api_hash):
        raise AssertionError("QR path is not used by this test")

    def poll_qr(self, client, login):
        raise AssertionError("QR path is not used by this test")

    def revoke(self, session, api_id, api_hash):
        return None


def test_phone_auth_returns_only_an_opaque_session_handle(monkeypatch):
    monkeypatch.setenv("TELEGRAM_MTPROTO_CLIENT_TOKEN", "test-token")
    storage = Storage()
    client = TestClient(create_app(storage=storage, gateway=Gateway()))
    headers = {"Authorization": "Bearer test-token"}

    start = client.post(
        "/auth/phone",
        headers=headers,
        json={"account_id": "ayaya-user-1", "phone": "+10000000000", "api_id": 123, "api_hash": "hash"},
    )
    assert start.status_code == 200
    assert start.json()["state"] == "awaiting_code"

    complete = client.post(
        "/auth/code",
        headers=headers,
        json={"account_id": "ayaya-user-1", "challenge_id": start.json()["challenge_id"], "code": "12345"},
    )

    assert complete.status_code == 200
    body = complete.json()
    assert body["state"] == "authenticated"
    assert body["session_handle"].startswith("opaque-session-handle-v1:")
    assert "telethon-session" not in body["session_handle"]
    assert len(storage.items) == 1
