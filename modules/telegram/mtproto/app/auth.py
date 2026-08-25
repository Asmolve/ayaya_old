import hmac

from fastapi import Header, HTTPException


def require_client_token(authorization: str | None = Header(default=None)) -> None:
    expected = __import__("os").environ.get("TELEGRAM_MTPROTO_CLIENT_TOKEN", "")
    supplied = authorization.removeprefix("Bearer ") if authorization else ""
    if not expected or not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="Unauthorized")
    if not hmac.compare_digest(supplied, expected):
        raise HTTPException(status_code=401, detail="Unauthorized")

