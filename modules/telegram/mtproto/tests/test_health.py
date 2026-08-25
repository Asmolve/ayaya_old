import pytest
from fastapi.testclient import TestClient

from app.main import create_app


@pytest.fixture
def client(monkeypatch):
    monkeypatch.setenv("TELEGRAM_MTPROTO_CLIENT_TOKEN", "test-token")
    monkeypatch.setenv("TELEGRAM_MTPROTO_SESSION_ENCRYPTION_KEY", "test-key")
    return TestClient(create_app(storage=FakeStorage()))


class FakeStorage:
    def ready(self):
        return True


def test_live_requires_bearer_token(client):
    response = client.get("/health/live")

    assert response.status_code == 401
    assert response.json() == {"detail": "Unauthorized"}


def test_live_returns_exact_contract(client):
    response = client.get("/health/live", headers={"Authorization": "Bearer test-token"})

    assert response.status_code == 200
    assert response.json() == {"status": "ok"}


def test_ready_returns_contract_when_storage_is_healthy(client):
    response = client.get("/health/ready", headers={"Authorization": "Bearer test-token"})

    assert response.status_code == 200
    assert response.json() == {
        "status": "ok",
        "ready": True,
        "contract": "opaque-session-handle.v1",
    }
