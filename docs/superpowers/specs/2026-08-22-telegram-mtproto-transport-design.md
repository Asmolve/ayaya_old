# Telegram MTProto Transport Design

## Goal

Add a private, PostgreSQL-backed MTProto transport service that satisfies the
existing `opaque-session-handle.v1` HTTP contract used by `telegram_app`.

## Architecture

`telegram_mtproto` is a standalone FastAPI service using Telethon. It is
reachable only on `ayaya_telegram_app_mtproto` and accepts the bearer token
configured by `TELEGRAM_MTPROTO_CLIENT_TOKEN`. It owns Telegram connection
material and returns only opaque session handles to the Rails application.

The service stores authenticated Telethon StringSessions encrypted with a
service encryption key in a dedicated PostgreSQL database. It stores an HMAC
digest of each opaque handle, never the plaintext handle. In-progress login
challenges remain in process memory so API hashes, login codes, and 2FA
passwords are never persisted.

## HTTP contract

- `GET /health/live` returns `{ "status": "ok" }` with a valid bearer token.
- `GET /health/ready` returns `{ "status": "ok", "ready": true, "contract": "opaque-session-handle.v1" }` when PostgreSQL is reachable.
- `POST /auth/phone`, `/auth/code`, `/auth/password`, `/auth/qr`, and `/auth/qr/poll` implement login challenges.
- `POST /imports` returns paginated dialog and folder state.
- `POST /state` returns current dialog-folder state.
- `POST /operations/apply` applies only the Rails-generated supported folder operations.
- `POST /auth/revoke` logs out the Telegram session and deletes its stored encrypted session.

All control requests contain `account_id`; authenticated requests also contain
`session_handle`. The service never accepts or returns a plaintext Telegram
session and never logs request bodies or credentials.

## PostgreSQL

The root Compose PostgreSQL instance provisions a dedicated role and database
for the transport. A one-shot migration container creates the `sessions` table
with account id, handle digest, encrypted session, timestamps, and a unique
account constraint. The transport receives `TELEGRAM_MTPROTO_DATABASE_URL` and
`TELEGRAM_MTPROTO_SESSION_ENCRYPTION_KEY` from `.env`.

## Security and failure behavior

- Bearer authentication is required for every endpoint, including health.
- Missing or invalid configuration makes readiness fail closed.
- Session encryption uses an authenticated Fernet key; handle lookup uses
  HMAC-SHA256 with the same key material.
- Telegram API ID/hash are supplied per login request and retained only in the
  in-memory challenge object until authentication completes.
- The service has no published host port and is attached only to the private
  MTProto and PostgreSQL networks.

## Verification

Tests cover bearer authentication, exact health payloads, encrypted PostgreSQL
session persistence, opaque-handle lookup, challenge lifecycle, Compose
service/network wiring, and the existing Rails transport contract.
