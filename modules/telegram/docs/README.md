# Telegram Dialog Organizer

`telegram` organizes local Telegram dialog folders under Ayaya. The bundle contains an Adapter Protocol v1 service and the `telegram_app` service boundary; Telegram domain behavior, migrations, and the internal app endpoint are implemented by the app service, not by the adapter.

## Services and topology

- `telegram_app` serves the authenticated UI on internal port `3000` and owns `ayaya_mod_telegram`; it is always started with `RAILS_ENV=production` and a module-specific `SECRET_KEY_BASE`.
- `telegram_database` idempotently provisions the dedicated `telegram` PostgreSQL role and `ayaya_mod_telegram` database before `telegram_migrate` runs. The app image never runs migrations during normal startup.
- `telegram_adapter` serves Adapter Protocol v1 on internal port `8080`.
- Root Compose (`name: ayaya`) provides the explicit private networks `ayaya_telegram_core_adapter`, `ayaya_telegram_adapter_app`, `ayaya_telegram_nginx_app`, `ayaya_telegram_app_postgres`, and `ayaya_telegram_app_mtproto`.
- Core reaches only `http://telegram_adapter:8080` through `ayaya_telegram_core_adapter`; the adapter reaches only `http://telegram_app:3000/internal/ayaya/status` through `ayaya_telegram_adapter_app` with its separate status secret.
- Platform NGINX reaches `telegram_app` only through `ayaya_telegram_nginx_app`; `telegram_app` reaches Postgres only through `ayaya_telegram_app_postgres` and the operator-provisioned MTProto transport only through `ayaya_telegram_app_mtproto`.
- `modules/telegram/compose.yml` is a non-deployable package topology descriptor. Root `compose.yml` is the only supported deployment flow.

Neither service publishes a host port. The mounted manifest is read-only and the adapter is stateless. Application state belongs in PostgreSQL database `ayaya_mod_telegram`; back up and restore that database separately from Core.

## Required environment

- `DATABASE_HOST`, `DATABASE_PORT`
- `TELEGRAM_DATABASE_NAME` (normally `ayaya_mod_telegram`)
- `TELEGRAM_DATABASE_USERNAME`, `TELEGRAM_DATABASE_PASSWORD` — the dedicated role provisioned by root Compose and used only by `telegram_app` and `telegram_migrate`
- `TELEGRAM_ADAPTER_SECRET` — shared only by Core and `telegram_adapter`; it must be non-empty and distinct from the internal status secret
- `TELEGRAM_INTERNAL_STATUS_SECRET` — shared only by `telegram_adapter` and `telegram_app`; it must be non-empty and differ from the adapter secret
- `TELEGRAM_ENVELOPE_KEY_FILE` — host path to the Docker-secret JSON keyring. The app receives it only as `/run/secrets/telegram_envelope_keyring`; its JSON must contain `current_key_id` and base64-encoded 32-byte entries in `keys`. Keep prior IDs during key rotation until all retained envelopes have expired.
- `TELEGRAM_SECRET_KEY_BASE` — production Rails secret for this module. It is distinct from both Adapter Protocol secrets and is supplied only to `telegram_app` and `telegram_migrate`.
- `TELEGRAM_TRUSTED_IDENTITY_SECRET` — the same non-empty secret received by Core and `telegram_app`, used only to HMAC the trusted NGINX identity headers; never give it to the adapter.
- `TELEGRAM_MTPROTO_CLIENT_URL` — mandatory URL of the private Telethon transport on `ayaya_telegram_app_mtproto`. The root bundle provides it as `http://telegram_mtproto:8081`; other production endpoints require HTTPS.
- `TELEGRAM_MTPROTO_CLIENT_TOKEN` — required production service-to-service bearer credential for that private transport
- `TELEGRAM_MTPROTO_DATABASE_NAME`, `TELEGRAM_MTPROTO_DATABASE_USERNAME`, `TELEGRAM_MTPROTO_DATABASE_PASSWORD` — dedicated PostgreSQL credentials for the transport-owned session store
- `TELEGRAM_MTPROTO_SESSION_ENCRYPTION_KEY` — Fernet key used to encrypt Telethon StringSessions before PostgreSQL persistence
- `TELEGRAM_APP_INTERNAL_STATUS_URL` — defaults to `http://telegram_app:3000/internal/ayaya/status`
- `TELEGRAM_MODULE_YML` — `/module/module.yml` in the adapter container

Do not bake these values, Telegram API credentials, opaque session handles, phone numbers, login codes, or message text into images, compose files, logs, or diagnostics.

## Build, migrate, start, and health

Deploy from the repository root with root Compose only. This is the single authoritative flow: it builds the app and adapter, provisions the dedicated database role/database, migrates it, and starts the health-gated services. Do not run `docker compose up` against `modules/telegram/compose.yml`; it intentionally has no deployable services.

```bash
docker compose --env-file .env up --build --wait telegram_adapter
```

The `telegram_database` and `telegram_migrate` one-shot services are explicit gated deploy steps; never run migrations automatically at application startup. The app and adapter both have Compose healthchecks; verify adapter readiness with root Compose:

```bash
docker compose --env-file .env exec telegram_adapter python -c 'import os, urllib.request; request = urllib.request.Request("http://127.0.0.1:8080/ayaya/health/ready", headers={"Authorization": "Bearer " + os.environ["TELEGRAM_ADAPTER_SECRET"]}); print(urllib.request.urlopen(request).read().decode())'
```

The command must return `"ready": true`. `live` alone proves only the adapter process is running. `ready` needs a valid manifest plus a reachable app with healthy app, database, and key-management components. A temporary Telegram API outage is reported as degraded status rather than leaking account state. Adapter status exposes only RFC3339 timestamps and allowlisted machine reasons; malformed parser/transport payloads become a safe `unreachable` status.

Before enabling a live account, check the private MTProto transport from `telegram_app`; both requests require the configured token and must match the exact JSON contracts in [CONTRACT.md](CONTRACT.md):

```bash
docker compose --env-file .env exec telegram_app sh -ec '
  curl -fsS -H "Authorization: Bearer $TELEGRAM_MTPROTO_CLIENT_TOKEN" "$TELEGRAM_MTPROTO_CLIENT_URL/health/live"
  curl -fsS -H "Authorization: Bearer $TELEGRAM_MTPROTO_CLIENT_TOKEN" "$TELEGRAM_MTPROTO_CLIENT_URL/health/ready"
'
```

The root bundle includes the `telegram_mtproto` service. It has no published
host port, uses the private MTProto network, and stores authenticated sessions
only in encrypted form in the dedicated PostgreSQL database. Start it with:

```bash
docker compose --env-file .env up --build --wait telegram_mtproto
```

Telegram `api_id` and `api_hash` are still required when starting a user login;
obtain them from [my.telegram.org](https://my.telegram.org). They are passed
through the private boundary for the live challenge and are not persisted by
the transport.

## Manual live Telegram smoke test

Run this only against an isolated, disposable Telegram test account after automated checks and both readiness commands succeed. Never paste credentials, login codes, session handles, or message text into tickets, shell history, or logs.

1. Deploy with the single root command above; confirm `telegram_database` completed, `telegram_migrate` completed, and `telegram_adapter` is healthy.
2. Verify Adapter `/ayaya/health/ready` and the private transport `/health/live` and `/health/ready` using the commands above. Confirm the ready response has `contract: "opaque-session-handle.v1"`.
3. Sign in to Ayaya as a non-admin test user and open `/m/telegram/` through NGINX. Confirm direct host-port access is unavailable and the UI remains reachable only through the authenticated route.
4. Complete a phone or QR login with the test account (and its 2FA password if configured). Inspect the application and transport logs only for redacted operational events; they must not contain a plaintext session, session handle, phone number, code, password, API hash, or message text.
5. Import the test account, create a preview plan, and verify it remains read-only until the explicit confirmation action. Execute one reversible, deliberately scoped folder change on the disposable account and confirm the resulting state matches the plan.
6. Disconnect the account. Confirm remote revocation succeeds, local account credentials are cleared, and the UI returns to a disconnected read-only state. Remove any test-only folders or dialogs created for the test.
7. Record only pass/fail results and redacted request IDs. If any check fails, stop the rollout, keep the account disconnected, and repair the private transport or deployment gate before retrying.

## NGINX and Core integration

Root runtime integration is in the tracked root Compose and NGINX configuration. The NGINX `/m/telegram/` location uses Core `auth_request`, `proxy_pass_request_headers off`, the seven signed trusted `X-Ayaya-*` headers listed in [CONTRACT.md](CONTRACT.md), and a narrow browser-header allowlist including `Sec-Fetch-*`. It does not add a public route for `/internal/ayaya/status`.

The production topology has no general app egress: all five Telegram networks are `internal: true`, and `telegram_app` is never joined to `default`. The dedicated MTProto network admits only the operator-provisioned transport. A future in-process client may add only a dedicated egress network with enforcement outside Compose that restricts destinations to Telegram infrastructure; it must not widen the private Core, Adapter, NGINX, Postgres, or MTProto networks.

Configure Core with only:

```dotenv
TELEGRAM_ADAPTER_URL=http://telegram_adapter:8080
TELEGRAM_ADAPTER_SECRET=the-same-value-used-by-telegram_adapter
TELEGRAM_TRUSTED_IDENTITY_SECRET=the-same-value-used-by-telegram_app
```

Core must not receive `TELEGRAM_INTERNAL_STATUS_SECRET` or any Telegram application secret, except the shared `TELEGRAM_TRUSTED_IDENTITY_SECRET` required to sign requests for `telegram_app`.

The Rails app keeps only encrypted opaque-handle/API-credential envelopes. Login codes and 2FA passwords are sent directly to the private MTProto boundary and are never persisted. Disconnect revokes the remote session first, then clears local credentials and account data transactionally; redacted operation metadata is retained only for its configured retention window.

## Rollback and recovery

Replace the adapter or app image with its prior compatible version, retain the read-only `module.yml` mount and both distinct secrets, then repeat the readiness check. Code rollback and database rollback are separate: use a reversible down migration only when explicitly supported; otherwise restore a verified `ayaya_mod_telegram` backup before starting the older app. Never delete the module database or its persistent storage as part of image rollback.
