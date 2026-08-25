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
  module_key: telegram
  name: Telegram Dialog Organizer
  version: 0.1.0
protocol:
  adapter_protocol_version: "1.0"
  capabilities: [manifest.v1, health.v1, status.v1]
routes:
  ui_base_path: /m/telegram
  api_base_path: /m/telegram/api
access:
  default_policy: authenticated
""".strip(),
        encoding="utf-8",
    )


def configure(monkeypatch, manifest_path: Path) -> None:
    monkeypatch.setenv("TELEGRAM_MODULE_YML", str(manifest_path))
    monkeypatch.setenv("TELEGRAM_ADAPTER_SECRET", "adapter-secret")
    monkeypatch.setenv("TELEGRAM_INTERNAL_STATUS_SECRET", "status-secret")
    monkeypatch.setenv(
        "TELEGRAM_APP_INTERNAL_STATUS_URL",
        "http://telegram-app/internal/ayaya/status",
    )


@pytest.fixture(autouse=True)
def clear_settings_cache():
    get_settings.cache_clear()
    yield
    get_settings.cache_clear()


def healthy_status(**overrides) -> dict:
    status = {
        "module_key": "telegram",
        "runtime_status": "healthy",
        "components": {
            "app": "healthy",
            "database": "healthy",
            "key_management": "healthy",
            "telegram": "healthy",
        },
        "checked_at": "2026-08-19T00:00:00Z",
        "degraded_reasons": [],
    }
    return {**status, **overrides}


def status_transport(status: dict, status_code: int = 200) -> httpx.MockTransport:
    def handler(request: httpx.Request) -> httpx.Response:
        assert request.url == httpx.URL("http://telegram-app/internal/ayaya/status")
        assert request.headers["Authorization"] == "Bearer status-secret"
        return httpx.Response(status_code, json=status)

    return httpx.MockTransport(handler)


def request(client: TestClient, path: str):
    return client.get(path, headers={"Authorization": "Bearer adapter-secret"})


def test_every_adapter_endpoint_requires_its_bearer_secret(tmp_path, monkeypatch):
    manifest_path = tmp_path / "module.yml"
    write_manifest(manifest_path)
    configure(monkeypatch, manifest_path)
    client = TestClient(create_app())

    for path in ("/ayaya/manifest", "/ayaya/health/live", "/ayaya/health/ready", "/ayaya/status"):
        assert client.get(path).status_code == 401


def test_adapter_does_not_expose_framework_documentation_endpoints(tmp_path, monkeypatch):
    manifest_path = tmp_path / "module.yml"
    write_manifest(manifest_path)
    configure(monkeypatch, manifest_path)
    client = TestClient(create_app())

    for path in ("/docs", "/redoc", "/openapi.json"):
        assert client.get(path).status_code == 404


@pytest.mark.parametrize(
    ("adapter_secret", "status_secret"),
    [
        ("", "status-secret"),
        ("adapter-secret", ""),
        ("shared-secret", "shared-secret"),
    ],
)
def test_adapter_fails_closed_when_control_and_internal_secrets_are_invalid(
    tmp_path, monkeypatch, adapter_secret, status_secret
):
    manifest_path = tmp_path / "module.yml"
    write_manifest(manifest_path)
    configure(monkeypatch, manifest_path)
    monkeypatch.setenv("TELEGRAM_ADAPTER_SECRET", adapter_secret)
    monkeypatch.setenv("TELEGRAM_INTERNAL_STATUS_SECRET", status_secret)
    client = TestClient(create_app(status_transport=status_transport(healthy_status())))

    for path in ("/ayaya/manifest", "/ayaya/health/live", "/ayaya/health/ready", "/ayaya/status"):
        response = client.get(path, headers={"Authorization": f"Bearer {adapter_secret}"})

        assert response.status_code == 503
        assert response.json() == {"detail": "Adapter secret configuration is invalid"}


def test_live_reports_only_adapter_process_liveness(tmp_path, monkeypatch):
    manifest_path = tmp_path / "module.yml"
    write_manifest(manifest_path)
    configure(monkeypatch, manifest_path)

    response = request(TestClient(create_app()), "/ayaya/health/live")

    assert response.status_code == 200
    assert response.json() == {"status": "ok", "component": "adapter"}


def test_ready_requires_a_valid_manifest_and_core_application_components(tmp_path, monkeypatch):
    manifest_path = tmp_path / "module.yml"
    write_manifest(manifest_path)
    configure(monkeypatch, manifest_path)
    client = TestClient(create_app(status_transport=status_transport(healthy_status())))

    response = request(client, "/ayaya/health/ready")

    assert response.status_code == 200
    assert response.json() == {"status": "ok", "component": "adapter", "ready": True}


@pytest.mark.parametrize(
    "status",
    [
        {"runtime_status": "unhealthy", "components": healthy_status()["components"]},
        {"runtime_status": "healthy", "components": {**healthy_status()["components"], "database": "unhealthy"}},
        {"runtime_status": "healthy", "components": {**healthy_status()["components"], "key_management": "unknown"}},
        {"runtime_status": "invented", "components": healthy_status()["components"]},
    ],
)
def test_ready_rejects_unavailable_or_malformed_telegram_app_status(tmp_path, monkeypatch, status):
    manifest_path = tmp_path / "module.yml"
    write_manifest(manifest_path)
    configure(monkeypatch, manifest_path)
    app_status = healthy_status(**status)

    response = request(
        TestClient(create_app(status_transport=status_transport(app_status))),
        "/ayaya/health/ready",
    )

    assert response.status_code == 503
    assert response.json() == {"status": "error", "component": "adapter", "ready": False}


def test_ready_allows_a_degraded_telegram_component_when_core_components_are_healthy(tmp_path, monkeypatch):
    manifest_path = tmp_path / "module.yml"
    write_manifest(manifest_path)
    configure(monkeypatch, manifest_path)
    app_status = healthy_status(
        runtime_status="degraded",
        components={**healthy_status()["components"], "telegram": "degraded"},
        degraded_reasons=["telegram_temporarily_unavailable"],
    )

    response = request(
        TestClient(create_app(status_transport=status_transport(app_status))),
        "/ayaya/health/ready",
    )

    assert response.status_code == 200
    assert response.json()["ready"] is True


def test_status_preserves_valid_telegram_degradation(tmp_path, monkeypatch):
    manifest_path = tmp_path / "module.yml"
    write_manifest(manifest_path)
    configure(monkeypatch, manifest_path)
    app_status = healthy_status(
        runtime_status="degraded",
        components={**healthy_status()["components"], "telegram": "degraded"},
        degraded_reasons=["telegram_temporarily_unavailable"],
    )

    response = request(
        TestClient(create_app(status_transport=status_transport(app_status))), "/ayaya/status"
    )

    assert response.status_code == 200
    assert response.json() == {
        "runtime_status": "degraded",
        "module_key": "telegram",
        "module_version": "0.1.0",
        "adapter_protocol_version": "1.0",
        "checked_at": "2026-08-19T00:00:00Z",
        "components": {"adapter": "healthy", **app_status["components"]},
        "degraded_reasons": ["telegram_temporarily_unavailable"],
    }


@pytest.mark.parametrize(
    ("component", "component_status", "expected_runtime_status"),
    [
        ("app", "degraded", "degraded"),
        ("database", "degraded", "degraded"),
        ("key_management", "degraded", "degraded"),
        ("telegram", "unhealthy", "unhealthy"),
        ("telegram", "unknown", "unreachable"),
    ],
)
def test_status_aggregates_every_required_component_without_false_healthy(
    tmp_path, monkeypatch, component, component_status, expected_runtime_status
):
    manifest_path = tmp_path / "module.yml"
    write_manifest(manifest_path)
    configure(monkeypatch, manifest_path)
    app_status = healthy_status(
        components={**healthy_status()["components"], component: component_status},
    )

    response = request(
        TestClient(create_app(status_transport=status_transport(app_status))), "/ayaya/status"
    )

    assert response.status_code == 200
    assert response.json()["runtime_status"] == expected_runtime_status


def test_status_only_exposes_allowlisted_degraded_reasons_and_no_hostile_payload(tmp_path, monkeypatch):
    manifest_path = tmp_path / "module.yml"
    write_manifest(manifest_path)
    configure(monkeypatch, manifest_path)
    app_status = healthy_status(
        runtime_status="degraded",
        components={**healthy_status()["components"], "telegram": "degraded"},
        degraded_reasons=[
            "telegram_temporarily_unavailable",
            "Bearer sensitive-status-secret",
            "phone=+15551234567",
        ],
    )
    app_status["session_string"] = "sensitive-session-string"

    response = request(
        TestClient(create_app(status_transport=status_transport(app_status))), "/ayaya/status"
    )

    assert response.status_code == 200
    assert response.json()["degraded_reasons"] == ["telegram_temporarily_unavailable"]
    assert "sensitive-status-secret" not in response.text
    assert "sensitive-session-string" not in response.text
    assert "+15551234567" not in response.text


@pytest.mark.parametrize("checked_at", ["not-a-timestamp", "2026-08-19 00:00:00Z", "2026-08-19T00:00:00"])
def test_status_rejects_non_rfc3339_checked_at_without_reflecting_payload(tmp_path, monkeypatch, checked_at):
    manifest_path = tmp_path / "module.yml"
    write_manifest(manifest_path)
    configure(monkeypatch, manifest_path)
    app_status = healthy_status(checked_at=checked_at)
    app_status["token"] = "sensitive-internal-token"

    response = request(
        TestClient(create_app(status_transport=status_transport(app_status))), "/ayaya/status"
    )

    assert response.status_code == 200
    assert response.json()["runtime_status"] == "unreachable"
    assert checked_at not in response.text
    assert "sensitive-internal-token" not in response.text


def test_status_maps_unreachable_or_invalid_internal_status_to_safe_unreachable(tmp_path, monkeypatch):
    manifest_path = tmp_path / "module.yml"
    write_manifest(manifest_path)
    configure(monkeypatch, manifest_path)

    def unreachable(request: httpx.Request) -> httpx.Response:
        raise httpx.ConnectError("unreachable", request=request)

    response = request(
        TestClient(create_app(status_transport=httpx.MockTransport(unreachable))),
        "/ayaya/status",
    )

    assert response.status_code == 200
    assert response.json()["runtime_status"] == "unreachable"
    assert response.json()["components"] == {
        "adapter": "healthy",
        "app": "unreachable",
        "database": "unknown",
        "key_management": "unknown",
        "telegram": "unknown",
    }
    assert response.json()["degraded_reasons"] == ["telegram_app_unreachable"]


@pytest.mark.parametrize(
    "transport",
    [
        httpx.MockTransport(
            lambda request: (_ for _ in ()).throw(httpx.ReadTimeout("timeout", request=request))
        ),
        httpx.MockTransport(lambda request: httpx.Response(200, content=b"not-json")),
    ],
)
def test_status_fault_injection_never_returns_transport_or_parser_details(tmp_path, monkeypatch, transport):
    manifest_path = tmp_path / "module.yml"
    write_manifest(manifest_path)
    configure(monkeypatch, manifest_path)

    response = request(TestClient(create_app(status_transport=transport)), "/ayaya/status")

    assert response.status_code == 200
    assert response.json()["runtime_status"] == "unreachable"
    assert "timeout" not in response.text
    assert "not-json" not in response.text


def test_status_rejects_a_mismatched_module_key_from_the_internal_app(tmp_path, monkeypatch):
    manifest_path = tmp_path / "module.yml"
    write_manifest(manifest_path)
    configure(monkeypatch, manifest_path)
    app_status = healthy_status(module_key="notes")

    response = request(
        TestClient(create_app(status_transport=status_transport(app_status))), "/ayaya/status"
    )

    assert response.status_code == 200
    assert response.json()["runtime_status"] == "unreachable"
