from __future__ import annotations

import json
import base64
import io
from dataclasses import dataclass
from hashlib import sha256

from telethon import TelegramClient
from telethon.errors import SessionPasswordNeededError
from telethon.sessions import StringSession
from telethon.tl import functions, types
import qrcode


@dataclass
class ClientResult:
    value: dict
    session: str | None = None


class TelethonGateway:
    async def _client(self, session: str, api_id: int, api_hash: str):
        client = TelegramClient(StringSession(session), api_id, api_hash)
        await client.connect()
        return client

    async def start_phone(self, phone: str, api_id: int, api_hash: str):
        return await self._start_phone(phone, api_id, api_hash)

    async def _start_phone(self, phone, api_id, api_hash):
        client = await self._client("", api_id, api_hash)
        result = await client.send_code_request(phone)
        return client, result.phone_code_hash

    async def submit_code(self, client, phone, phone_code_hash, code):
        return await self._submit_code(client, phone, phone_code_hash, code)

    async def _submit_code(self, client, phone, phone_code_hash, code):
        try:
            await client.sign_in(phone=phone, code=code, phone_code_hash=phone_code_hash)
        except SessionPasswordNeededError:
            return {"state": "awaiting_password"}, None
        return await self._authenticated(client)

    async def submit_password(self, client, password):
        return await self._submit_password(client, password)

    async def _submit_password(self, client, password):
        await client.sign_in(password=password)
        return await self._authenticated(client)

    async def _authenticated(self, client):
        me = await client.get_me()
        return {
            "state": "authenticated",
            "telegram_account_id": str(me.id),
            "display_name": " ".join(filter(None, [me.first_name, me.last_name])) or me.username,
        }, StringSession.save(client.session)

    async def start_qr(self, api_id: int, api_hash: str):
        return await self._start_qr(api_id, api_hash)

    async def _start_qr(self, api_id, api_hash):
        client = await self._client("", api_id, api_hash)
        login = await client.qr_login()
        image = qrcode.make(login.url)
        stream = io.BytesIO()
        image.save(stream, format="PNG")
        return client, login, "data:image/png;base64," + base64.b64encode(stream.getvalue()).decode("ascii")

    async def poll_qr(self, client, login):
        return await self._poll_qr(client, login)

    async def _poll_qr(self, client, login):
        await login.wait()
        return await self._authenticated(client)

    async def revoke(self, session: str, api_id: int, api_hash: str):
        return await self._revoke(session, api_id, api_hash)

    async def _revoke(self, session, api_id, api_hash):
        client = await self._client(session, api_id, api_hash)
        await client.log_out()
        await client.disconnect()

    async def state(self, session: str, api_id: int, api_hash: str):
        return await self._state(session, api_id, api_hash)

    async def import_state(self, session: str, api_id: int, api_hash: str, cursor: str | None = None):
        return await self._import_state(session, api_id, api_hash, cursor)

    async def _import_state(self, session, api_id, api_hash, cursor):
        state = await self._state(session, api_id, api_hash)
        return {"state": state, "cursor": None, "complete": True}

    async def apply(self, session: str, api_id: int, api_hash: str, request: dict):
        return await self._apply(session, api_id, api_hash, request)

    async def _apply(self, session, api_id, api_hash, request):
        client = await self._client(session, api_id, api_hash)
        try:
            rpc = request.get("rpc")
            payload = request.get("request", request)
            if rpc == "update_dialog_filter":
                folder = payload["folder"]
                await client(functions.messages.UpdateDialogFilterRequest(
                    id=int(folder["telegram_folder_id"]),
                    filter=self._to_filter(folder),
                ))
            elif rpc == "update_dialog_filters_order":
                await client(functions.messages.UpdateDialogFilterOrderRequest(
                    order=[int(value) for value in payload["folder_order"]]
                ))
            else:
                raise ValueError("unsupported MTProto operation")
            return {"status": "applied"}
        finally:
            await client.disconnect()

    def _to_filter(self, folder):
        return types.DialogFilter(
            id=int(folder["telegram_folder_id"]),
            title=types.TextWithEntities(text=str(folder.get("title", "Telegram")), entities=[]),
            emoticon=folder.get("emoji"),
            pinned_peers=[self._to_peer(peer) for peer in folder.get("pinned_peers", [])],
            include_peers=[self._to_peer(peer) for peer in folder.get("include_peers", [])],
            exclude_peers=[self._to_peer(peer) for peer in folder.get("exclude_peers", [])],
            contacts=False,
            non_contacts=False,
            groups=False,
            broadcasts=False,
            bots=False,
            exclude_muted=False,
            exclude_read=False,
            exclude_archived=False,
        )

    def _to_peer(self, peer):
        kind = peer.get("kind")
        peer_id = int(peer["id"])
        access_hash = peer.get("access_hash")
        if kind == "user":
            return types.InputPeerUser(peer_id, int(access_hash or 0))
        if kind == "channel":
            return types.InputPeerChannel(peer_id, int(access_hash or 0))
        return types.InputPeerChat(peer_id)

    async def _state(self, session, api_id, api_hash):
        client = await self._client(session, api_id, api_hash)
        try:
            dialogs = await self._dialogs(client)
            folders, order = await self._folders(client)
            return {"dialogs": dialogs, "folders": folders, "folder_order": order, "app_config": {}}
        finally:
            await client.disconnect()

    async def _dialogs(self, client):
        result = []
        async for dialog in client.iter_dialogs():
            entity = dialog.entity
            peer_kind = "channel" if isinstance(entity, types.Channel) else "user" if isinstance(entity, types.User) else "chat"
            result.append(
                {
                    "peer_kind": peer_kind,
                    "peer_id": str(entity.id),
                    "input_peer_ref": json.dumps({"kind": peer_kind, "id": entity.id, "access_hash": getattr(entity, "access_hash", None)}),
                    "access_hash": getattr(entity, "access_hash", None),
                    "title": dialog.title or "",
                    "username": getattr(entity, "username", None),
                    "avatar_url": None,
                    "metadata_hash": sha256(json.dumps({"id": entity.id, "title": dialog.title}, sort_keys=True).encode()).hexdigest(),
                }
            )
        return result

    async def _folders(self, client):
        response = await client(functions.messages.GetDialogFiltersRequest())
        folders = [self._folder_from_filter(item) for item in response.filters if isinstance(item, types.DialogFilter)]
        return folders, [folder["telegram_folder_id"] for folder in folders]

    def _folder_from_filter(self, item):
        def peers(values):
            return [{"id": str(peer.channel_id if hasattr(peer, "channel_id") else peer.user_id if hasattr(peer, "user_id") else peer.chat_id), "kind": self._peer_kind(peer), "access_hash": getattr(peer, "access_hash", None)} for peer in values]

        return {
            "telegram_folder_id": int(item.id),
            "title": item.title if isinstance(item.title, str) else item.title.text,
            "emoji": getattr(item, "emoticon", None),
            "mode": "showcase",
            "include_peers": peers(getattr(item, "include_peers", [])),
            "exclude_peers": peers(getattr(item, "exclude_peers", [])),
            "pinned_peers": peers(getattr(item, "pinned_peers", [])),
            "flags": {},
        }

    def _peer_kind(self, peer):
        if isinstance(peer, types.InputPeerChannel):
            return "channel"
        if isinstance(peer, types.InputPeerUser):
            return "user"
        return "chat"
