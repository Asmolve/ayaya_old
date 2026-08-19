from pathlib import Path

import pytest
from fastapi.testclient import TestClient

from app.main import create_app
from app.settings import get_settings


EXPECTED_MANIFEST = {
    "identity": {
        "module_key": "planning",
        "name": "Planning",
        "version": "0.1.0",
    },
    "protocol": {
        "adapter_protocol_version": "1.0",
        "capabilities": ["manifest.v1", "health.v1", "status.v1"],
    },
    "routes": {
        "ui_base_path": "/m/planning",
        "api_base_path": "/m/planning/api",
    },
    "access": {"default_policy": "authenticated"},
}


@pytest.fixture(autouse=True)
def clear_settings_cache():
    get_settings.cache_clear()
    yield
    get_settings.cache_clear()


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


def test_manifest_requires_adapter_secret(tmp_path, monkeypatch):
    manifest_path = tmp_path / "module.yml"
    write_manifest(manifest_path)
    monkeypatch.setenv("PLANNING_MODULE_YML", str(manifest_path))
    monkeypatch.setenv("PLANNING_ADAPTER_SECRET", "secret")

    response = TestClient(create_app()).get("/ayaya/manifest")

    assert response.status_code == 401


def test_manifest_returns_module_yml(tmp_path, monkeypatch):
    manifest_path = tmp_path / "module.yml"
    write_manifest(manifest_path)
    monkeypatch.setenv("PLANNING_MODULE_YML", str(manifest_path))
    monkeypatch.setenv("PLANNING_ADAPTER_SECRET", "secret")

    response = TestClient(create_app()).get(
        "/ayaya/manifest",
        headers={"Authorization": "Bearer secret"},
    )

    assert response.status_code == 200
    assert response.json() == EXPECTED_MANIFEST
