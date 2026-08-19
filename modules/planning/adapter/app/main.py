from datetime import datetime, timezone
from typing import Any

import httpx
from fastapi import Depends, FastAPI
from fastapi.responses import JSONResponse

from .auth import require_adapter_secret
from .manifest import load_manifest
from .settings import Settings, get_settings
from .status_client import fetch_planning_app_status


def status_fields(app_status: dict[str, Any]) -> tuple[str, dict[str, Any], str, list[Any]]:
    runtime_status = app_status.get("runtime_status", "unhealthy")
    components = app_status.get("components", {})
    checked_at = app_status.get("checked_at") or datetime.now(timezone.utc).isoformat()
    degraded_reasons = app_status.get("degraded_reasons", [])

    if not isinstance(runtime_status, str):
        raise ValueError("planning app runtime status must be a string")
    if not isinstance(components, dict):
        raise ValueError("planning app components must be a mapping")
    if not isinstance(checked_at, str):
        raise ValueError("planning app checked_at must be a string")
    if not isinstance(degraded_reasons, list):
        raise ValueError("planning app degraded reasons must be a list")

    return runtime_status, components, checked_at, degraded_reasons


def create_app(status_transport: httpx.BaseTransport | None = None) -> FastAPI:
    app = FastAPI(title="Ayaya Planning Adapter")

    @app.get("/ayaya/manifest", dependencies=[Depends(require_adapter_secret)])
    def manifest(settings: Settings = Depends(get_settings)):
        return load_manifest(settings.module_yml)

    @app.get("/ayaya/health/live", dependencies=[Depends(require_adapter_secret)])
    def live():
        return {"status": "ok", "component": "adapter"}

    @app.get("/ayaya/health/ready", dependencies=[Depends(require_adapter_secret)])
    def ready(settings: Settings = Depends(get_settings)):
        try:
            load_manifest(settings.module_yml)
            app_status = fetch_planning_app_status(settings, transport=status_transport)
            runtime_status, components, _, _ = status_fields(app_status)
            if runtime_status != "healthy" or components.get("database") != "healthy":
                raise ValueError("planning app is not healthy")
            return {"status": "ok", "component": "adapter", "ready": True}
        except Exception:
            return JSONResponse(
                status_code=503,
                content={"status": "error", "component": "adapter", "ready": False},
            )

    @app.get("/ayaya/status", dependencies=[Depends(require_adapter_secret)])
    def status(settings: Settings = Depends(get_settings)):
        manifest_data = load_manifest(settings.module_yml)
        try:
            app_status = fetch_planning_app_status(settings, transport=status_transport)
            runtime_status, components, checked_at, degraded_reasons = status_fields(app_status)
        except (httpx.HTTPError, ValueError):
            runtime_status = "unreachable"
            components = {"app": "unreachable", "database": "unknown"}
            checked_at = datetime.now(timezone.utc).isoformat()
            degraded_reasons = ["planning_app_unreachable"]

        components = {"adapter": "healthy", **components}
        return {
            "runtime_status": runtime_status,
            "module_key": manifest_data["identity"]["module_key"],
            "module_version": manifest_data["identity"]["version"],
            "adapter_protocol_version": manifest_data["protocol"]["adapter_protocol_version"],
            "checked_at": checked_at,
            "components": components,
            "degraded_reasons": degraded_reasons,
        }

    return app


app = create_app()
