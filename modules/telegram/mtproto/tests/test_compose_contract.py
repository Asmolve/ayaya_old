from pathlib import Path

import yaml


ROOT = Path("/compose.yml") if Path("/compose.yml").exists() else Path(__file__).parents[3] / "compose.yml"


def test_root_compose_has_private_postgres_backed_transport():
    compose = yaml.safe_load(ROOT.read_text())
    services = compose["services"]

    assert services["telegram_mtproto"]["networks"] == [
        "telegram_app_postgres",
        "telegram_app_mtproto",
    ]
    assert "ports" not in services["telegram_mtproto"]
    assert services["telegram_mtproto"]["depends_on"]["telegram_mtproto_migrate"]["condition"] == "service_completed_successfully"
    assert services["telegram_mtproto_migrate"]["depends_on"]["telegram_database"]["condition"] == "service_completed_successfully"
    assert "TELEGRAM_MTPROTO_DATABASE_URL" in services["telegram_mtproto"]["environment"]
    assert "TELEGRAM_MTPROTO_SESSION_ENCRYPTION_KEY" in services["telegram_mtproto"]["environment"]
