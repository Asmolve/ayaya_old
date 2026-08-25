from pathlib import Path
from typing import Any

import yaml


REQUIRED_CAPABILITIES = frozenset({"manifest.v1", "health.v1", "status.v1"})
ACCESS_POLICIES = frozenset({"authenticated", "admin_only", "manual"})
MODULE_KEY = "telegram"
MANIFEST_FIELDS = frozenset({"identity", "protocol", "presentation", "routes", "access"})
SECTION_FIELDS = {
    "identity": frozenset({"module_key", "name", "version"}),
    "protocol": frozenset({"adapter_protocol_version", "capabilities"}),
    "presentation": frozenset({"description", "icon", "category"}),
    "routes": frozenset({"ui_base_path", "api_base_path"}),
    "access": frozenset({"default_policy"}),
}


class ManifestValidationError(ValueError):
    """Raised when package truth cannot safely be exposed as runtime truth."""


def _section(manifest: dict[str, Any], name: str) -> dict[str, Any]:
    value = manifest.get(name)
    if not isinstance(value, dict):
        raise ManifestValidationError(f"{name} must be a mapping")
    return value


def _required_string(section: dict[str, Any], name: str) -> str:
    value = section.get(name)
    if not isinstance(value, str) or not value.strip():
        raise ManifestValidationError(f"{name} must be a non-empty string")
    return value


def _only_known_fields(section: dict[str, Any], name: str) -> None:
    if not set(section).issubset(SECTION_FIELDS[name]):
        raise ManifestValidationError(f"{name} contains unsupported fields")


def validate_manifest(manifest: Any) -> dict[str, Any]:
    if not isinstance(manifest, dict):
        raise ManifestValidationError("module.yml must contain a mapping")
    if not set(manifest).issubset(MANIFEST_FIELDS):
        raise ManifestValidationError("module.yml contains unsupported fields")

    identity = _section(manifest, "identity")
    _only_known_fields(identity, "identity")
    if _required_string(identity, "module_key") != MODULE_KEY:
        raise ManifestValidationError("identity.module_key must be telegram")
    _required_string(identity, "name")
    _required_string(identity, "version")

    protocol = _section(manifest, "protocol")
    _only_known_fields(protocol, "protocol")
    version = _required_string(protocol, "adapter_protocol_version")
    if version.split(".", maxsplit=1)[0] != "1":
        raise ManifestValidationError("adapter protocol major version is unsupported")
    capabilities = protocol.get("capabilities")
    if not isinstance(capabilities, list) or not all(isinstance(item, str) for item in capabilities):
        raise ManifestValidationError("protocol.capabilities must be a list of strings")
    if not REQUIRED_CAPABILITIES.issubset(capabilities):
        raise ManifestValidationError("protocol.capabilities is missing a required v1 capability")

    routes = _section(manifest, "routes")
    _only_known_fields(routes, "routes")
    if _required_string(routes, "ui_base_path") != "/m/telegram":
        raise ManifestValidationError("routes.ui_base_path must equal /m/telegram")
    if _required_string(routes, "api_base_path") != "/m/telegram/api":
        raise ManifestValidationError("routes.api_base_path must equal /m/telegram/api")

    access = _section(manifest, "access")
    _only_known_fields(access, "access")
    if _required_string(access, "default_policy") not in ACCESS_POLICIES:
        raise ManifestValidationError("access.default_policy is unsupported")

    presentation = manifest.get("presentation")
    if presentation is not None and not isinstance(presentation, dict):
        raise ManifestValidationError("presentation must be a mapping")
    if presentation is not None:
        _only_known_fields(presentation, "presentation")

    return manifest


def load_manifest(path: str) -> dict[str, Any]:
    try:
        with Path(path).open("r", encoding="utf-8") as file:
            loaded = yaml.safe_load(file)
    except (OSError, yaml.YAMLError) as error:
        raise ManifestValidationError("module.yml cannot be read") from error
    return validate_manifest(loaded)
