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
  module_key: planning
  name: Planning
  version: 0.1.0
protocol:
  adapter_protocol_version: "1.0"
  capabilities:
    - manifest.v1
    - health.v1
    - status.v1
routes:
  ui_base_path: /m/planning
  api_base_path: /m/planning/api
access:
  default_policy: authenticated
""".strip(),
        encoding="utf-8",
    )


def configure(monkeypatch, manifest_path: Path) -> None:
    monkeypatch.setenv("PLANNING_MODULE_YML", str(manifest_path))
    monkeypatch.setenv("PLANNING_ADAPTER_SECRET", "secret")
    monkeypatch.setenv("PLANNING_INTERNAL_STATUS_SECRET", "internal")
    monkeypatch.setenv(
        "PLANNING_APP_INTERNAL_STATUS_URL",
        "http://planning-app/internal/ayaya/status",
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

    assert TestClient(create_app()).get("/ayaya/health/live").status_code == 401


def test_live_returns_ok(tmp_path, monkeypatch):
    manifest_path = tmp_path / "module.yml"
    write_manifest(manifest_path)
    configure(monkeypatch, manifest_path)

    response = TestClient(create_app()).get(
        "/ayaya/health/live",
        headers={"Authorization": "Bearer secret"},
    )

    assert response.status_code == 200
    assert response.json() == {"status": "ok", "component": "adapter"}


@pytest.mark.parametrize("path", ["/ayaya/health/ready", "/ayaya/status"])
def test_ready_and_status_reject_missing_adapter_secret(tmp_path, monkeypatch, path):
    manifest_path = tmp_path / "module.yml"
    write_manifest(manifest_path)
    configure(monkeypatch, manifest_path)

    response = TestClient(create_app()).get(path)

    assert response.status_code == 401


@pytest.mark.parametrize("path", ["/ayaya/health/ready", "/ayaya/status"])
def test_ready_and_status_reject_wrong_adapter_secret(tmp_path, monkeypatch, path):
    manifest_path = tmp_path / "module.yml"
    write_manifest(manifest_path)
    configure(monkeypatch, manifest_path)

    response = TestClient(create_app()).get(
        path,
        headers={"Authorization": "Bearer wrong-secret"},
    )

    assert response.status_code == 401


def status_transport(status: dict) -> httpx.MockTransport:
    def handler(request: httpx.Request) -> httpx.Response:
        assert request.headers["Authorization"] == "Bearer internal"
        return httpx.Response(200, json=status)

    return httpx.MockTransport(handler)


def test_ready_returns_unavailable_when_planning_app_is_unreachable(tmp_path, monkeypatch):
    manifest_path = tmp_path / "module.yml"
    write_manifest(manifest_path)
    configure(monkeypatch, manifest_path)

    def handler(request: httpx.Request) -> httpx.Response:
        raise httpx.ConnectError("unreachable", request=request)

    response = TestClient(create_app(status_transport=httpx.MockTransport(handler))).get(
        "/ayaya/health/ready",
        headers={"Authorization": "Bearer secret"},
    )

    assert response.status_code == 503
    assert response.json()["ready"] is False


def test_ready_returns_unavailable_when_planning_app_status_is_malformed(tmp_path, monkeypatch):
    manifest_path = tmp_path / "module.yml"
    write_manifest(manifest_path)
    configure(monkeypatch, manifest_path)
    app = create_app(
        status_transport=status_transport(
            {"module_key": "planning", "runtime_status": "healthy", "components": ["not-a-mapping"]}
        )
    )

    response = TestClient(app).get(
        "/ayaya/health/ready",
        headers={"Authorization": "Bearer secret"},
    )

    assert response.status_code == 503
    assert response.json() == {"status": "error", "component": "adapter", "ready": False}


def test_ready_reflects_an_unhealthy_planning_database(tmp_path, monkeypatch):
    manifest_path = tmp_path / "module.yml"
    write_manifest(manifest_path)
    configure(monkeypatch, manifest_path)
    app = create_app(
        status_transport=status_transport(
            {
                "module_key": "planning",
                "runtime_status": "healthy",
                "components": {"app": "healthy", "database": "unhealthy"},
                "checked_at": "2026-08-19T00:00:00Z",
                "degraded_reasons": ["database_unavailable"],
            }
        )
    )

    response = TestClient(app).get(
        "/ayaya/health/ready",
        headers={"Authorization": "Bearer secret"},
    )

    assert response.status_code == 503
    assert response.json() == {"status": "error", "component": "adapter", "ready": False}


@pytest.mark.parametrize(
    ("path", "expected_status"),
    [("/ayaya/health/ready", 503), ("/ayaya/status", 200)],
)
def test_health_endpoints_reject_a_planning_status_with_missing_or_wrong_module_key(
    tmp_path, monkeypatch, path, expected_status
):
    manifest_path = tmp_path / "module.yml"
    write_manifest(manifest_path)
    configure(monkeypatch, manifest_path)
    status = {
        "runtime_status": "healthy",
        "components": {"app": "healthy", "database": "healthy"},
        "checked_at": "2026-08-19T00:00:00Z",
        "degraded_reasons": [],
    }
    for module_key in (None, "notes"):
        invalid_status = status if module_key is None else {**status, "module_key": module_key}
        response = TestClient(create_app(status_transport=status_transport(invalid_status))).get(
            path,
            headers={"Authorization": "Bearer secret"},
        )

        assert response.status_code == expected_status
        if path == "/ayaya/health/ready":
            assert response.json() == {"status": "error", "component": "adapter", "ready": False}
        else:
            assert response.json()["runtime_status"] == "unreachable"


def test_status_maps_planning_app_status(tmp_path, monkeypatch):
    manifest_path = tmp_path / "module.yml"
    write_manifest(manifest_path)
    configure(monkeypatch, manifest_path)
    app = create_app(
        status_transport=status_transport(
            {
                "module_key": "planning",
                "runtime_status": "healthy",
                "components": {"app": "healthy", "database": "healthy"},
                "checked_at": "2026-08-19T00:00:00Z",
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
    assert body["module_key"] == "planning"
    assert body["module_version"] == "0.1.0"
    assert body["components"]["database"] == "healthy"


def test_status_maps_malformed_planning_app_status_to_unreachable(tmp_path, monkeypatch):
    manifest_path = tmp_path / "module.yml"
    write_manifest(manifest_path)
    configure(monkeypatch, manifest_path)
    app = create_app(
        status_transport=status_transport(
            {"module_key": "planning", "runtime_status": "healthy", "components": ["not-a-mapping"]}
        )
    )

    response = TestClient(app).get(
        "/ayaya/status",
        headers={"Authorization": "Bearer secret"},
    )

    assert response.status_code == 200
    assert response.json()["runtime_status"] == "unreachable"
    assert response.json()["degraded_reasons"] == ["planning_app_unreachable"]


@pytest.mark.parametrize(
    "status",
    [
        {"module_key": "planning", "runtime_status": "invented", "components": {"app": "healthy", "database": "healthy"}},
        {"module_key": "planning", "runtime_status": "healthy", "components": {"database": "healthy"}},
        {"module_key": "planning", "runtime_status": "healthy", "components": {"app": "healthy"}},
    ],
)
def test_status_degrades_invalid_runtime_contracts(tmp_path, monkeypatch, status):
    manifest_path = tmp_path / "module.yml"
    write_manifest(manifest_path)
    configure(monkeypatch, manifest_path)
    app = create_app(status_transport=status_transport(status))

    response = TestClient(app).get(
        "/ayaya/status",
        headers={"Authorization": "Bearer secret"},
    )

    assert response.status_code == 200
    assert response.json()["runtime_status"] == "unreachable"
    assert response.json()["components"] == {"adapter": "healthy", "app": "unreachable", "database": "unknown"}


@pytest.mark.parametrize(
    ("status", "expected_runtime_status"),
    [
        (
            {
                "module_key": "planning",
                "runtime_status": "healthy",
                "components": {"app": "unknown", "database": "healthy"},
                "checked_at": "2026-08-19T00:00:00Z",
                "degraded_reasons": [],
            },
            "unreachable",
        ),
        (
            {
                "module_key": "planning",
                "runtime_status": "healthy",
                "components": {"app": "healthy", "database": "unhealthy"},
                "checked_at": "2026-08-19T00:00:00Z",
                "degraded_reasons": [],
            },
            "unhealthy",
        ),
    ],
)
def test_status_never_publishes_healthy_for_unknown_or_contradictory_components(
    tmp_path, monkeypatch, status, expected_runtime_status
):
    manifest_path = tmp_path / "module.yml"
    write_manifest(manifest_path)
    configure(monkeypatch, manifest_path)
    app = create_app(status_transport=status_transport(status))

    response = TestClient(app).get(
        "/ayaya/status",
        headers={"Authorization": "Bearer secret"},
    )

    assert response.status_code == 200
    assert response.json()["runtime_status"] == expected_runtime_status
