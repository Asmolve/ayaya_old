from typing import Any

import httpx

from .settings import Settings


def fetch_notes_app_status(
    settings: Settings,
    transport: httpx.BaseTransport | None = None,
) -> dict[str, Any]:
    headers = {"Authorization": f"Bearer {settings.internal_status_secret}"}
    with httpx.Client(transport=transport, timeout=2.0) as client:
        response = client.get(settings.notes_app_internal_status_url, headers=headers)
        if response.status_code == 503:
            data = response.json()
        else:
            response.raise_for_status()
            data = response.json()

    if not isinstance(data, dict):
        raise ValueError("notes app status must be an object")
    return data
