from fastapi import Depends, Header, HTTPException

from .settings import Settings, get_settings


def require_adapter_secret(
    authorization: str | None = Header(default=None),
    settings: Settings = Depends(get_settings),
) -> None:
    expected = f"Bearer {settings.adapter_secret}"
    if not settings.adapter_secret or authorization != expected:
        raise HTTPException(status_code=401, detail="Unauthorized")
