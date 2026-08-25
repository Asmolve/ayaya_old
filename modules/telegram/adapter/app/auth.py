import hmac

from fastapi import Depends, Header, HTTPException

from .settings import Settings, get_settings


def require_adapter_secret(
    authorization: str | None = Header(default=None),
    settings: Settings = Depends(get_settings),
) -> None:
    if not settings.secrets_are_valid():
        raise HTTPException(status_code=503, detail="Adapter secret configuration is invalid")

    expected = f"Bearer {settings.adapter_secret}"
    if not settings.adapter_secret or not authorization or not hmac.compare_digest(authorization, expected):
        raise HTTPException(status_code=401, detail="Unauthorized")
