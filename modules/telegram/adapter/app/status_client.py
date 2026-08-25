from typing import Any

import httpx

from .settings import Settings


def fetch_telegram_app_status(
    settings: Settings,
    transport: httpx.BaseTransport | None = None,
) -> dict[str, Any]:
    if not settings.secrets_are_valid():
        raise ValueError("internal status configuration is invalid")

    headers = {"Authorization": f"Bearer {settings.internal_status_secret}"}
    with httpx.Client(transport=transport, timeout=2.0) as client:
        response = client.get(settings.telegram_app_internal_status_url, headers=headers)
        if response.status_code != 503:
            response.raise_for_status()
        data = response.json()

    if not isinstance(data, dict):
        raise ValueError("telegram app status must be an object")
    return data
