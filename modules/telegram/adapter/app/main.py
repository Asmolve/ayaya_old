from datetime import datetime, timezone
import re
from typing import Any

import httpx
from fastapi import Depends, FastAPI, HTTPException
from fastapi.responses import JSONResponse

from .auth import require_adapter_secret
from .manifest import ManifestValidationError, load_manifest
from .settings import Settings, get_settings
from .status_client import fetch_telegram_app_status


RUNTIME_STATUSES = frozenset({"healthy", "degraded", "unhealthy", "unreachable", "incompatible"})
COMPONENT_STATUSES = RUNTIME_STATUSES | {"unknown"}
REQUIRED_COMPONENTS = ("app", "database", "key_management", "telegram")
CORE_COMPONENTS = ("app", "database", "key_management")
ALLOWED_DEGRADED_REASONS = frozenset(
    {
        "database_unavailable",
        "key_management_unavailable",
        "telegram_app_unreachable",
        "telegram_not_checked",
        "telegram_temporarily_unavailable",
    }
)
RFC3339_TIMESTAMP = re.compile(
    r"^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d+)?(?:Z|[+-]\d{2}:\d{2})$"
)
STATUS_SEVERITY = {
    "healthy": 0,
    "degraded": 1,
    "unhealthy": 2,
    "incompatible": 2,
    "unreachable": 3,
}


def rfc3339_now() -> str:
    return datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")


def valid_rfc3339(value: str) -> bool:
    if not RFC3339_TIMESTAMP.fullmatch(value):
        return False
    try:
        datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError:
        return False
    return True


def component_runtime_status(components: dict[str, str]) -> str:
    statuses = [components[component] for component in REQUIRED_COMPONENTS]
    if any(status in {"unknown", "unreachable"} for status in statuses):
        return "unreachable"
    if any(status in {"unhealthy", "incompatible"} for status in statuses):
        return "unhealthy"
    if "degraded" in statuses:
        return "degraded"
    return "healthy"


def sanitized_degraded_reasons(value: Any) -> list[str]:
    if not isinstance(value, list):
        return []
    return list(
        dict.fromkeys(
            reason
            for reason in value
            if isinstance(reason, str) and reason in ALLOWED_DEGRADED_REASONS
        )
    )


def status_fields(app_status: dict[str, Any]) -> tuple[str, dict[str, str], str, list[str]]:
    if app_status.get("module_key") != "telegram":
        raise ValueError("telegram app module key is invalid")

    runtime_status = app_status.get("runtime_status")
    if runtime_status not in RUNTIME_STATUSES:
        raise ValueError("telegram app runtime status is invalid")

    components = app_status.get("components")
    if not isinstance(components, dict):
        raise ValueError("telegram app components must be a mapping")
    if any(components.get(component) not in COMPONENT_STATUSES for component in REQUIRED_COMPONENTS):
        raise ValueError("telegram app component status is invalid")

    checked_at = app_status.get("checked_at")
    if not isinstance(checked_at, str) or not valid_rfc3339(checked_at):
        raise ValueError("telegram app checked_at must be RFC3339")

    normalized_components = {component: components[component] for component in REQUIRED_COMPONENTS}
    aggregated_status = component_runtime_status(normalized_components)
    if STATUS_SEVERITY[aggregated_status] > STATUS_SEVERITY[runtime_status]:
        runtime_status = aggregated_status

    return runtime_status, normalized_components, checked_at, sanitized_degraded_reasons(
        app_status.get("degraded_reasons", [])
    )


def app_is_ready(runtime_status: str, components: dict[str, str]) -> bool:
    return runtime_status in {"healthy", "degraded"} and all(
        components[component] == "healthy" for component in CORE_COMPONENTS
    )


def unavailable_status() -> tuple[str, dict[str, str], str, list[str]]:
    return (
        "unreachable",
        {
            "app": "unreachable",
            "database": "unknown",
            "key_management": "unknown",
            "telegram": "unknown",
        },
        rfc3339_now(),
        ["telegram_app_unreachable"],
    )


def create_app(status_transport: httpx.BaseTransport | None = None) -> FastAPI:
    app = FastAPI(
        title="Ayaya Telegram Adapter",
        docs_url=None,
        redoc_url=None,
        openapi_url=None,
    )

    @app.get("/ayaya/manifest", dependencies=[Depends(require_adapter_secret)])
    def manifest(settings: Settings = Depends(get_settings)):
        try:
            return load_manifest(settings.module_yml)
        except ManifestValidationError as error:
            raise HTTPException(status_code=503, detail="Adapter manifest is invalid") from error

    @app.get("/ayaya/health/live", dependencies=[Depends(require_adapter_secret)])
    def live():
        return {"status": "ok", "component": "adapter"}

    @app.get("/ayaya/health/ready", dependencies=[Depends(require_adapter_secret)])
    def ready(settings: Settings = Depends(get_settings)):
        try:
            load_manifest(settings.module_yml)
            runtime_status, components, _, _ = status_fields(
                fetch_telegram_app_status(settings, transport=status_transport)
            )
            if not app_is_ready(runtime_status, components):
                raise ValueError("telegram app is not ready")
            return {"status": "ok", "component": "adapter", "ready": True}
        except (httpx.HTTPError, ManifestValidationError, ValueError):
            return JSONResponse(
                status_code=503,
                content={"status": "error", "component": "adapter", "ready": False},
            )

    @app.get("/ayaya/status", dependencies=[Depends(require_adapter_secret)])
    def status(settings: Settings = Depends(get_settings)):
        try:
            manifest_data = load_manifest(settings.module_yml)
        except ManifestValidationError as error:
            raise HTTPException(status_code=503, detail="Adapter manifest is invalid") from error

        try:
            runtime_status, components, checked_at, degraded_reasons = status_fields(
                fetch_telegram_app_status(settings, transport=status_transport)
            )
        except (httpx.HTTPError, ValueError):
            runtime_status, components, checked_at, degraded_reasons = unavailable_status()

        return {
            "runtime_status": runtime_status,
            "module_key": manifest_data["identity"]["module_key"],
            "module_version": manifest_data["identity"]["version"],
            "adapter_protocol_version": manifest_data["protocol"]["adapter_protocol_version"],
            "checked_at": checked_at,
            "components": {"adapter": "healthy", **components},
            "degraded_reasons": degraded_reasons,
        }

    return app


app = create_app()
