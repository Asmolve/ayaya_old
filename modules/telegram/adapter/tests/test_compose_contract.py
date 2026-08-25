from pathlib import Path

import yaml


MODULE_DIR = Path(__file__).parents[2]


def test_module_bundle_compose_is_a_non_deployable_root_topology_descriptor():
    compose = yaml.safe_load((MODULE_DIR / "compose.yml").read_text())

    assert compose["services"] == {}
    assert compose["x-ayaya-telegram-topology"]["authoritative_deployment"] == "../../compose.yml"
    assert compose["x-ayaya-telegram-topology"]["deploy_command"] == (
        "docker compose --env-file .env -f compose.yml up --build --wait telegram_adapter"
    )
    assert compose["networks"] == {
        "telegram_core_adapter": {"external": True, "name": "ayaya_telegram_core_adapter"},
        "telegram_adapter_app": {"external": True, "name": "ayaya_telegram_adapter_app"},
        "telegram_nginx_app": {"external": True, "name": "ayaya_telegram_nginx_app"},
        "telegram_app_postgres": {"external": True, "name": "ayaya_telegram_app_postgres"},
        "telegram_app_mtproto": {"external": True, "name": "ayaya_telegram_app_mtproto"},
    }


def test_module_bundle_uses_a_non_root_production_image_and_a_self_contained_default_test_image():
    dockerfile = (MODULE_DIR / "adapter" / "Dockerfile").read_text()
    assert "COPY module.yml /module.yml" in dockerfile
    assert "COPY compose.yml /compose.yml" in dockerfile
    assert "COPY adapter/Dockerfile ./Dockerfile" in dockerfile
    assert dockerfile.index("FROM base AS production") < dockerfile.index("FROM base AS test")
    assert "ENV PYTHONPATH=/adapter" in dockerfile
    assert 'CMD ["pytest", "-q"]' in dockerfile
    assert "USER adapter:adapter" in dockerfile


def test_production_requirements_exclude_test_only_dependencies():
    production = (MODULE_DIR / "adapter" / "requirements.txt").read_text().splitlines()
    test_requirements = (MODULE_DIR / "adapter" / "requirements-test.txt").read_text().splitlines()

    assert not any(requirement.startswith("pytest") for requirement in production)
    assert "-r requirements.txt" in test_requirements
    assert any(requirement.startswith("pytest") for requirement in test_requirements)
