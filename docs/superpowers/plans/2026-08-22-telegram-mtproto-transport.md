# Telegram MTProto Transport Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a private FastAPI/Telethon transport backed by PostgreSQL and wire it into root Compose.

**Architecture:** The transport owns Telethon sessions and exposes the existing `opaque-session-handle.v1` HTTP boundary. Auth challenges stay in memory; authenticated StringSessions are encrypted into a dedicated PostgreSQL database and addressed by HMAC handle digests.

**Tech Stack:** Python 3.12, FastAPI, Uvicorn, Telethon, psycopg, cryptography/Fernet, PostgreSQL 16.

**Spec:** `docs/superpowers/specs/2026-08-22-telegram-mtproto-transport-design.md`

## Global Constraints

- The transport must require `Authorization: Bearer <TELEGRAM_MTPROTO_CLIENT_TOKEN>`.
- The transport must return only opaque session handles and never plaintext Telegram sessions.
- The transport must not persist API hashes, login codes, 2FA passwords, phone numbers, or message text.
- The transport must expose exact `/health/live` and `/health/ready` contracts from `modules/telegram/docs/CONTRACT.md`.
- The service must have no published host port and must use the private MTProto network.

### Task 1: Create the transport package and dependency contract

**Files:**
- Create: `modules/telegram/mtproto/Dockerfile`
- Create: `modules/telegram/mtproto/requirements.txt`
- Create: `modules/telegram/mtproto/app/__init__.py`
- Create: `modules/telegram/mtproto/app/settings.py`
- Create: `modules/telegram/mtproto/app/auth.py`
- Create: `modules/telegram/mtproto/tests/test_health.py`

- [ ] Write failing tests asserting missing bearer tokens return 401, valid tokens reach the handler, and `/health/live` returns exactly `{"status":"ok"}`.
- [ ] Run `pytest -q modules/telegram/mtproto/tests/test_health.py`; expect import/app failures because the package is absent.
- [ ] Implement settings loading and constant-time bearer validation.
- [ ] Implement the FastAPI app and exact live/readiness route shape, with readiness depending on a storage health function.
- [ ] Add Telethon, FastAPI, Uvicorn, psycopg, and cryptography dependencies and a non-root production image.
- [ ] Run the focused tests and confirm they pass.

### Task 2: Add encrypted PostgreSQL session storage

**Files:**
- Create: `modules/telegram/mtproto/app/storage.py`
- Create: `modules/telegram/mtproto/app/migrate.py`
- Create: `modules/telegram/mtproto/tests/test_storage.py`

- [ ] Write failing tests for schema creation, encrypted session insertion, handle digest lookup, account uniqueness, and deletion.
- [ ] Run `pytest -q modules/telegram/mtproto/tests/test_storage.py`; expect missing module failures.
- [ ] Implement a psycopg-backed repository with SQL DDL, Fernet encryption for StringSessions, and HMAC-SHA256 handle digests.
- [ ] Ensure repository test helpers inspect database rows only through test fixtures and assert plaintext session text is absent.
- [ ] Implement `python -m app.migrate` for the one-shot Compose migration container.
- [ ] Run focused storage tests against a disposable PostgreSQL test database or skip only when no PostgreSQL server is available, reporting the exact limitation.

### Task 3: Implement login challenge lifecycle and session handles

**Files:**
- Create: `modules/telegram/mtproto/app/challenges.py`
- Create: `modules/telegram/mtproto/app/telegram_client.py`
- Create: `modules/telegram/mtproto/app/routes_auth.py`
- Create: `modules/telegram/mtproto/tests/test_auth_routes.py`
- Modify: `modules/telegram/mtproto/app/main.py`

- [ ] Write failing route tests for phone start, code submission, 2FA password submission, QR start/poll, authenticated response shape, and revocation.
- [ ] Run the focused auth tests and verify they fail before implementation.
- [ ] Implement an in-memory challenge registry containing only live Telethon client objects and challenge IDs; do not serialize API hashes or codes.
- [ ] Implement Telethon login calls and convert successful authentication to a random `opaque-session-handle-v1:<base64url>` handle.
- [ ] Persist the authenticated StringSession through the storage repository and return only `session_handle`.
- [ ] Implement revoke to call Telethon logout, delete the database row, and invalidate the handle.
- [ ] Run the focused auth tests with a deterministic injected Telethon fake and confirm they pass.

### Task 4: Implement state, import, and folder operations

**Files:**
- Create: `modules/telegram/mtproto/app/routes_state.py`
- Create: `modules/telegram/mtproto/app/operations.py`
- Create: `modules/telegram/mtproto/tests/test_state_routes.py`
- Modify: `modules/telegram/mtproto/app/main.py`

- [ ] Write failing tests for handle-required requests, paginated imports, state normalization, supported folder create/update/delete/reorder operations, and rejection of unsupported operations.
- [ ] Run the focused tests and verify they fail for the missing routes.
- [ ] Resolve a stored handle to an encrypted session, create a short-lived Telethon client, and disconnect it after each request.
- [ ] Implement dialog metadata import and Telegram dialog-filter reads without persisting message text.
- [ ] Implement the exact operation names emitted by `MtprotoClient` (`update_dialog_filter` and `update_dialog_filters_order`) with bounded input validation.
- [ ] Run focused state/operation tests and confirm they pass.

### Task 5: Wire PostgreSQL provisioning and Compose networking

**Files:**
- Modify: `compose.yml`
- Modify: `.env.example`
- Modify: `modules/telegram/docs/README.md`
- Modify: `modules/telegram/docs/CONTRACT.md`
- Create: `modules/telegram/mtproto/tests/test_compose_contract.py`

- [ ] Write failing Compose contract tests for `telegram_mtproto`, its migration dependency, private networks, dedicated database variables, and absence of published ports.
- [ ] Run the focused Compose tests and verify they fail before Compose changes.
- [ ] Extend the existing Telegram database provisioner to create a dedicated MTProto role/database, add `telegram_mtproto_migrate`, and add the `telegram_mtproto` service.
- [ ] Connect the transport to `telegram_app_mtproto` and `telegram_app_postgres`; keep it off the default network and do not publish a host port.
- [ ] Add generated-secret placeholders and the required database/key variables to `.env.example`, preserving the local `.env` as ignored state.
- [ ] Document build, migration, health checks, and the need for Telegram `api_id/api_hash` from `my.telegram.org`.
- [ ] Run Compose YAML parsing and contract tests.

### Task 6: Full verification and handoff

**Files:**
- Modify: `graphify-out/` via `graphify update .` after code changes.

- [ ] Run `pytest -q modules/telegram/mtproto/tests modules/telegram/adapter/tests`.
- [ ] Run the project’s relevant Ruby tests for the Telegram transport contract.
- [ ] Run `docker compose --env-file .env config`.
- [ ] If Docker is available, build the new image and run the migration/health path with the configured PostgreSQL instance.
- [ ] Run `graphify update .` and inspect the final diff for accidental secrets or generated artifacts.
- [ ] Report exact verification results and any remaining external prerequisite: a valid Telegram `api_id/api_hash` and an account login.
