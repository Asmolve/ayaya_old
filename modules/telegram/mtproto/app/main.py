from fastapi import Depends, FastAPI, HTTPException

from .auth import require_client_token
from .challenges import ChallengeRegistry
from .routes_auth import router as auth_router
from .routes_state import router as state_router
from .settings import Settings
from .storage import SessionStorage
from .telegram_client import TelethonGateway


CONTRACT = "opaque-session-handle.v1"


def create_app(storage=None, gateway=None, challenges=None) -> FastAPI:
    app = FastAPI(docs_url=None, redoc_url=None, openapi_url=None)
    settings = Settings.from_environment()
    app.state.storage = storage or SessionStorage(
        settings.database_url, settings.session_encryption_key
    )
    app.state.gateway = gateway or TelethonGateway()
    app.state.challenges = challenges or ChallengeRegistry()

    @app.get("/health/live", dependencies=[Depends(require_client_token)])
    def live():
        return {"status": "ok"}

    @app.get("/health/ready", dependencies=[Depends(require_client_token)])
    def ready():
        if not app.state.storage.ready():
            raise HTTPException(status_code=503, detail="Not ready")
        return {"status": "ok", "ready": True, "contract": CONTRACT}

    app.include_router(auth_router(app.state.storage, app.state.gateway, app.state.challenges))
    app.include_router(state_router(app.state.storage, app.state.gateway))

    return app
