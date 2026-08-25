from fastapi.testclient import TestClient

from app.main import create_app
from app.storage import StoredSession


class Storage:
    def ready(self):
        return True

    def fetch(self, account_id, handle):
        if account_id == "account" and handle == "opaque-session-handle-v1:valid":
            return StoredSession(account_id, "encrypted-telethon-session")
        return None


class Gateway:
    def import_state(self, session, api_id, api_hash, cursor):
        assert (session, api_id, api_hash, cursor) == (
            "encrypted-telethon-session", 123, "hash", "next"
        )
        return {"state": {"dialogs": [], "folders": [], "folder_order": [], "app_config": {}}, "cursor": None, "complete": True}

    def state(self, session, api_id, api_hash):
        return {"dialogs": [], "folders": [], "folder_order": [], "app_config": {}}

    def apply(self, session, api_id, api_hash, request):
        return {"status": "applied"}


def test_import_requires_an_opaque_handle_and_forwards_api_credentials(monkeypatch):
    monkeypatch.setenv("TELEGRAM_MTPROTO_CLIENT_TOKEN", "test-token")
    client = TestClient(create_app(storage=Storage(), gateway=Gateway()))

    response = client.post(
        "/imports",
        headers={"Authorization": "Bearer test-token"},
        json={
            "account_id": "account",
            "session_handle": "opaque-session-handle-v1:valid",
            "api_id": 123,
            "api_hash": "hash",
            "cursor": "next",
        },
    )

    assert response.status_code == 200
    assert response.json()["complete"] is True


def test_import_rejects_unknown_handle(monkeypatch):
    monkeypatch.setenv("TELEGRAM_MTPROTO_CLIENT_TOKEN", "test-token")
    client = TestClient(create_app(storage=Storage(), gateway=Gateway()))

    response = client.post(
        "/imports",
        headers={"Authorization": "Bearer test-token"},
        json={"account_id": "account", "session_handle": "opaque-session-handle-v1:unknown", "api_id": 123, "api_hash": "hash"},
    )

    assert response.status_code == 401
