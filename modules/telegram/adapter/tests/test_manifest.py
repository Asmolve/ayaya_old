from pathlib import Path

import pytest
import yaml
from fastapi.testclient import TestClient

from app.main import create_app
from app.settings import get_settings


SHIPPED_MANIFEST_PATH = Path(__file__).parents[2] / "module.yml"


@pytest.fixture(autouse=True)
def clear_settings_cache():
    get_settings.cache_clear()
    yield
    get_settings.cache_clear()


def valid_manifest() -> str:
    return """
identity:
  module_key: telegram
  name: Telegram Dialog Organizer
  version: 0.1.0
protocol:
  adapter_protocol_version: "1.0"
  capabilities:
    - manifest.v1
    - health.v1
    - status.v1
presentation:
  description: Local Telegram dialog organization
  icon: messages-square
  category: productivity
routes:
  ui_base_path: /m/telegram
  api_base_path: /m/telegram/api
access:
  default_policy: authenticated
""".strip()


def configure(monkeypatch, manifest_path: Path) -> None:
    monkeypatch.setenv("TELEGRAM_MODULE_YML", str(manifest_path))
    monkeypatch.setenv("TELEGRAM_ADAPTER_SECRET", "adapter-secret")
    monkeypatch.setenv("TELEGRAM_INTERNAL_STATUS_SECRET", "status-secret")
    monkeypatch.setenv(
        "TELEGRAM_APP_INTERNAL_STATUS_URL",
        "http://telegram-app/internal/ayaya/status",
    )


def test_manifest_requires_the_configured_bearer_secret(tmp_path, monkeypatch):
    manifest_path = tmp_path / "module.yml"
    manifest_path.write_text(valid_manifest(), encoding="utf-8")
    configure(monkeypatch, manifest_path)
    client = TestClient(create_app())

    assert client.get("/ayaya/manifest").status_code == 401
    assert client.get(
        "/ayaya/manifest", headers={"Authorization": "Bearer wrong-secret"}
    ).status_code == 401
    assert client.get(
        "/ayaya/manifest", headers={"Authorization": "Basic adapter-secret"}
    ).status_code == 401


def test_manifest_returns_the_validated_shipped_package_manifest(monkeypatch):
    configure(monkeypatch, SHIPPED_MANIFEST_PATH)

    response = TestClient(create_app()).get(
        "/ayaya/manifest", headers={"Authorization": "Bearer adapter-secret"}
    )

    assert response.status_code == 200
    assert response.json() == yaml.safe_load(SHIPPED_MANIFEST_PATH.read_text())


@pytest.mark.parametrize(
    "replacement",
    [
        "module_key: telegram-app",
        "adapter_protocol_version: \"2.0\"",
        "api_base_path: /m/telegram-api",
        "default_policy: public",
    ],
)
def test_manifest_endpoint_rejects_invalid_package_manifest(tmp_path, monkeypatch, replacement):
    manifest_path = tmp_path / "module.yml"
    invalid = valid_manifest()
    if replacement.startswith("module_key"):
        invalid = invalid.replace("module_key: telegram", replacement)
    elif replacement.startswith("adapter_protocol_version"):
        invalid = invalid.replace('adapter_protocol_version: "1.0"', replacement)
    elif replacement.startswith("api_base_path"):
        invalid = invalid.replace("api_base_path: /m/telegram/api", replacement)
    else:
        invalid = invalid.replace("default_policy: authenticated", replacement)
    manifest_path.write_text(invalid, encoding="utf-8")
    configure(monkeypatch, manifest_path)

    response = TestClient(create_app()).get(
        "/ayaya/manifest", headers={"Authorization": "Bearer adapter-secret"}
    )

    assert response.status_code == 503
    assert response.json() == {"detail": "Adapter manifest is invalid"}


def test_manifest_endpoint_rejects_uncontracted_package_fields(tmp_path, monkeypatch):
    manifest_path = tmp_path / "module.yml"
    manifest_path.write_text(
        valid_manifest() + "\noperational:\n  support_token: sensitive-package-token\n",
        encoding="utf-8",
    )
    configure(monkeypatch, manifest_path)

    response = TestClient(create_app()).get(
        "/ayaya/manifest", headers={"Authorization": "Bearer adapter-secret"}
    )

    assert response.status_code == 503
    assert "sensitive-package-token" not in response.text
