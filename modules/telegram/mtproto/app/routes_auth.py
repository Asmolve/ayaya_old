from __future__ import annotations

import inspect
import secrets
from datetime import datetime, timedelta, timezone

from fastapi import APIRouter, Depends, HTTPException

from .auth import require_client_token
from .challenges import Challenge, ChallengeRegistry
from .handles import new_handle


def router(storage, gateway, challenges: ChallengeRegistry):
    api = APIRouter(dependencies=[Depends(require_client_token)])

    def credentials(payload):
        try:
            return int(payload["api_id"]), str(payload["api_hash"])
        except (KeyError, TypeError, ValueError) as error:
            raise HTTPException(status_code=422, detail="api_id and api_hash are required") from error

    def authenticated(payload, result, challenge):
        handle = new_handle()
        storage.save(payload["account_id"], handle, result["session"])
        return {
            "state": "authenticated",
            "session_handle": handle,
            "telegram_account_id": result["telegram_account_id"],
            "display_name": result.get("display_name"),
        }

    async def call(method, *args):
        value = method(*args)
        return await value if inspect.isawaitable(value) else value

    @api.post("/auth/phone")
    async def phone(payload: dict):
        api_id, api_hash = credentials(payload)
        client, phone_code_hash = await call(gateway.start_phone, payload["phone"], api_id, api_hash)
        challenge_id = secrets.token_urlsafe(24)
        challenges.put(challenge_id, Challenge(payload["account_id"], client, "phone", payload["phone"], phone_code_hash))
        return {"state": "awaiting_code", "challenge_id": challenge_id, "expires_at": (datetime.now(timezone.utc) + timedelta(minutes=5)).isoformat().replace("+00:00", "Z"), "api_credentials": {"api_id": api_id, "api_hash": api_hash}}

    @api.post("/auth/code")
    async def code(payload: dict):
        challenge = challenges.get(payload["challenge_id"])
        result, session = await call(gateway.submit_code, challenge.client, challenge.phone, challenge.phone_code_hash, payload["code"])
        if result["state"] == "awaiting_password":
            return {"state": "awaiting_password", "challenge_id": payload["challenge_id"]}
        result["session"] = session
        challenges.pop(payload["challenge_id"])
        return authenticated(payload | {"account_id": challenge.account_id}, result, challenge)

    @api.post("/auth/password")
    async def password(payload: dict):
        challenge = challenges.get(payload["challenge_id"])
        result, session = await call(gateway.submit_password, challenge.client, payload["password"])
        result["session"] = session
        challenges.pop(payload["challenge_id"])
        return authenticated(payload | {"account_id": challenge.account_id}, result, challenge)

    @api.post("/auth/qr")
    async def qr(payload: dict):
        api_id, api_hash = credentials(payload)
        client, login, qr_url = await call(gateway.start_qr, api_id, api_hash)
        challenge_id = secrets.token_urlsafe(24)
        challenges.put(challenge_id, Challenge(payload["account_id"], client, "qr", qr_login=login))
        return {"state": "awaiting_qr", "challenge_id": challenge_id, "qr_data_uri": qr_url, "api_credentials": {"api_id": api_id, "api_hash": api_hash}}

    @api.post("/auth/qr/poll")
    async def qr_poll(payload: dict):
        challenge = challenges.get(payload["challenge_id"])
        result, session = await call(gateway.poll_qr, challenge.client, challenge.qr_login)
        result["session"] = session
        challenges.pop(payload["challenge_id"])
        return authenticated(payload | {"account_id": challenge.account_id}, result, challenge)

    @api.post("/auth/revoke")
    async def revoke(payload: dict):
        stored = storage.fetch(payload["account_id"], payload["session_handle"])
        if not stored:
            raise HTTPException(status_code=404, detail="Session not found")
        api_id, api_hash = credentials(payload)
        await call(gateway.revoke, stored.session, api_id, api_hash)
        storage.delete(payload["account_id"], payload["session_handle"])
        return {"state": "revoked"}

    return api
