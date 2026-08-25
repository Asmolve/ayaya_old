import secrets


def new_handle() -> str:
    return "opaque-session-handle-v1:" + secrets.token_urlsafe(32)

