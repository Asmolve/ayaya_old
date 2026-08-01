from pathlib import Path

import httpx
import pytest
from fastapi.testclient import TestClient

from app.main import create_app
from app.settings import get_settings


def write_manifest(path: Path) -> None:
    path.write_text(
        """
identity:
  module_key: notes
  name: Notes
  version: 0.1.0
protocol:
  adapter_protocol_version: "1.0"
  capabilities:
    - manifest.v1
    - health.v1
    - status.v1
routes:
  ui_base_path: /m/notes
  api_base_path: /m/notes/api
access:
  default_policy: authenticated
""".strip(),
        encoding="utf-8",
    )


def configure(monkeypatch, manifest_path: Path):
    monkeypatch.setenv("NOTES_MODULE_YML", str(manifest_path))
    monkeypatch.setenv("NOTES_ADAPTER_SECRET", "secret")
    monkeypatch.setenv("NOTES_INTERNAL_STATUS_SECRET", "internal")
    monkeypatch.setenv(
        "NOTES_APP_INTERNAL_STATUS_URL",
        "http://notes-app/internal/ayaya/status",
    )


@pytest.fixture(autouse=True)
def clear_settings_cache():
    get_settings.cache_clear()
    yield
    get_settings.cache_clear()


def test_live_requires_adapter_secret(tmp_path, monkeypatch):
    manifest_path = tmp_path / "module.yml"
    write_manifest(manifest_path)
    configure(monkeypatch, manifest_path)
    client = TestClient(create_app())

    assert client.get("/ayaya/health/live").status_code == 401


def test_live_returns_ok(tmp_path, monkeypatch):
    manifest_path = tmp_path / "module.yml"
    write_manifest(manifest_path)
    configure(monkeypatch, manifest_path)
    client = TestClient(create_app())

    response = client.get(
        "/ayaya/health/live",
        headers={"Authorization": "Bearer secret"},
    )

    assert response.status_code == 200
    assert response.json() == {"status": "ok", "component": "adapter"}


def status_transport(status: dict) -> httpx.MockTransport:
    def handler(request: httpx.Request) -> httpx.Response:
        assert request.headers["Authorization"] == "Bearer internal"
        return httpx.Response(200, json=status)

    return httpx.MockTransport(handler)


def test_status_maps_notes_app_status(tmp_path, monkeypatch):
    manifest_path = tmp_path / "module.yml"
    write_manifest(manifest_path)
    configure(monkeypatch, manifest_path)
    app = create_app(
        status_transport=status_transport(
            {
                "module_key": "notes",
                "runtime_status": "healthy",
                "components": {"app": "healthy", "database": "healthy"},
                "checked_at": "2026-08-01T00:00:00Z",
                "degraded_reasons": [],
            }
        )
    )
    response = TestClient(app).get(
        "/ayaya/status",
        headers={"Authorization": "Bearer secret"},
    )

    assert response.status_code == 200
    body = response.json()
    assert body["runtime_status"] == "healthy"
    assert body["module_version"] == "0.1.0"
    assert body["adapter_protocol_version"] == "1.0"
    assert body["components"]["database"] == "healthy"


def test_status_preserves_notes_app_unhealthy(tmp_path, monkeypatch):
    manifest_path = tmp_path / "module.yml"
    write_manifest(manifest_path)
    configure(monkeypatch, manifest_path)
    app = create_app(
        status_transport=status_transport(
            {
                "runtime_status": "unhealthy",
                "components": {"app": "unhealthy", "database": "healthy"},
                "degraded_reasons": ["app_unhealthy"],
            }
        )
    )
    response = TestClient(app).get(
        "/ayaya/status",
        headers={"Authorization": "Bearer secret"},
    )

    assert response.status_code == 200
    assert response.json()["runtime_status"] == "unhealthy"
    assert response.json()["components"]["app"] == "unhealthy"


def test_ready_fails_when_notes_app_status_is_unreachable(tmp_path, monkeypatch):
    manifest_path = tmp_path / "module.yml"
    write_manifest(manifest_path)
    configure(monkeypatch, manifest_path)
    def handler(request: httpx.Request) -> httpx.Response:
        raise httpx.ConnectError("unreachable", request=request)

    app = create_app(status_transport=httpx.MockTransport(handler))
    response = TestClient(app).get(
        "/ayaya/health/ready",
        headers={"Authorization": "Bearer secret"},
    )

    assert response.status_code == 503
    assert response.json()["ready"] is False


def test_ready_fails_when_notes_app_reports_unhealthy(tmp_path, monkeypatch):
    manifest_path = tmp_path / "module.yml"
    write_manifest(manifest_path)
    configure(monkeypatch, manifest_path)
    app = create_app(
        status_transport=status_transport(
            {"runtime_status": "unhealthy", "components": {"app": "unhealthy"}}
        )
    )
    response = TestClient(app).get(
        "/ayaya/health/ready",
        headers={"Authorization": "Bearer secret"},
    )

    assert response.status_code == 503
    assert response.json()["ready"] is False


def test_status_preserves_http_503_notes_app_status(tmp_path, monkeypatch):
    manifest_path = tmp_path / "module.yml"
    write_manifest(manifest_path)
    configure(monkeypatch, manifest_path)

    def handler(request: httpx.Request) -> httpx.Response:
        assert request.headers["Authorization"] == "Bearer internal"
        return httpx.Response(
            503,
            json={
                "runtime_status": "unhealthy",
                "components": {"app": "healthy", "database": "unhealthy"},
                "degraded_reasons": ["database_unavailable"],
            },
        )

    app = create_app(status_transport=httpx.MockTransport(handler))
    response = TestClient(app).get(
        "/ayaya/status",
        headers={"Authorization": "Bearer secret"},
    )

    assert response.status_code == 200
    body = response.json()
    assert body["runtime_status"] == "unhealthy"
    assert body["components"]["database"] == "unhealthy"
    assert body["degraded_reasons"] == ["database_unavailable"]


def test_status_maps_invalid_notes_app_response_to_unreachable(tmp_path, monkeypatch):
    manifest_path = tmp_path / "module.yml"
    write_manifest(manifest_path)
    configure(monkeypatch, manifest_path)
    app = create_app(
        status_transport=httpx.MockTransport(
            lambda request: httpx.Response(200, json=["invalid"])
        )
    )
    response = TestClient(app).get(
        "/ayaya/status",
        headers={"Authorization": "Bearer secret"},
    )

    assert response.status_code == 200
    assert response.json()["runtime_status"] == "unreachable"
    assert response.json()["degraded_reasons"] == ["notes_app_unreachable"]
