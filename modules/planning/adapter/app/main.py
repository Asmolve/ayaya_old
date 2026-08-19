from datetime import datetime, timezone

import httpx
from fastapi import Depends, FastAPI
from fastapi.responses import JSONResponse

from .auth import require_adapter_secret
from .manifest import load_manifest
from .settings import Settings, get_settings
from .status_client import fetch_planning_app_status


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
            if app_status.get("runtime_status") != "healthy":
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
            runtime_status = app_status.get("runtime_status", "unhealthy")
            components = app_status.get("components", {})
            checked_at = app_status.get("checked_at") or datetime.now(timezone.utc).isoformat()
            degraded_reasons = app_status.get("degraded_reasons", [])
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
