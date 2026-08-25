import inspect

from fastapi import APIRouter, Depends, HTTPException

from .auth import require_client_token


def router(storage, gateway):
    api = APIRouter(dependencies=[Depends(require_client_token)])

    def session(payload):
        account_id = payload.get("account_id")
        handle = payload.get("session_handle")
        if not account_id or not handle:
            raise HTTPException(status_code=422, detail="account_id and session_handle are required")
        stored = storage.fetch(account_id, handle)
        if not stored:
            raise HTTPException(status_code=401, detail="Session not found")
        try:
            return stored, int(payload["api_id"]), str(payload["api_hash"])
        except (KeyError, TypeError, ValueError) as error:
            raise HTTPException(status_code=422, detail="api_id and api_hash are required") from error

    async def call(method, *args):
        value = method(*args)
        return await value if inspect.isawaitable(value) else value

    @api.post("/imports")
    async def imports(payload: dict):
        stored, api_id, api_hash = session(payload)
        return await call(gateway.import_state, stored.session, api_id, api_hash, payload.get("cursor"))

    @api.post("/state")
    async def state(payload: dict):
        stored, api_id, api_hash = session(payload)
        return await call(gateway.state, stored.session, api_id, api_hash)

    @api.post("/operations/apply")
    async def apply(payload: dict):
        stored, api_id, api_hash = session(payload)
        if payload.get("confirmed") is not True:
            raise HTTPException(status_code=422, detail="confirmed is required")
        return await call(gateway.apply, stored.session, api_id, api_hash, payload)

    return api
