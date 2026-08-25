# Telegram Dialog Organizer Contract

Core communicates only with `telegram_adapter`; it never receives a `telegram_app` URL or the internal status secret. The adapter fails closed if either `TELEGRAM_ADAPTER_SECRET` or `TELEGRAM_INTERNAL_STATUS_SECRET` is blank, or if the two values are equal.

User traffic reaches `telegram_app` only through platform NGINX at `/m/telegram`. The exact app route is `/m/telegram/` (and its `/m/telegram/api` namespace); no public NGINX route may expose `/internal/ayaya/status`.

`telegram_adapter` reads `/module/module.yml` as package truth. All Adapter Protocol v1 endpoints require `Authorization: Bearer <TELEGRAM_ADAPTER_SECRET>`:

- `GET /ayaya/manifest`
- `GET /ayaya/health/live`
- `GET /ayaya/health/ready`
- `GET /ayaya/status`

`telegram_adapter` obtains runtime status only from `GET /internal/ayaya/status` on `telegram_app`, using the separate `TELEGRAM_INTERNAL_STATUS_SECRET`. The app response has no account, session, credential, phone-number, message, or other user data. It reports `app`, `database`, `key_management`, and `telegram` components. The adapter accepts only RFC3339 `checked_at` values and a fixed allowlist of machine-readable degraded reasons; unrecognised reasons and all other payload fields are discarded. Any `unknown` or `unreachable` required component makes the aggregate status `unreachable`; any `unhealthy` or `incompatible` component makes it `unhealthy`; any `degraded` component makes it `degraded`. Therefore a required component can never coexist with an aggregate `healthy` status.

Readiness succeeds only when the mounted manifest is valid and the app, database, and key-management components are healthy. A valid degraded Telegram component remains available to the control plane. Unreachable or malformed app status maps to a safe `unreachable` adapter status.

The package manifest is a closed Adapter Protocol v1 boundary: only the documented `identity`, `protocol`, optional `presentation`, `routes`, and `access` fields (and their documented child keys) are served. Unsupported fields make the manifest unavailable rather than becoming a control-plane data channel.

The package topology descriptor does not create an alternate shared network. Root `compose.yml` is the sole supported deployment flow and attaches services to the explicit private root networks `ayaya_telegram_core_adapter`, `ayaya_telegram_adapter_app`, `ayaya_telegram_nginx_app`, `ayaya_telegram_app_postgres`, and `ayaya_telegram_app_mtproto`. Before `telegram_migrate`, root Compose idempotently provisions the dedicated Telegram PostgreSQL role and database; the app and migration job use only those credentials. Root topology limits connectivity to Core↔Adapter, Adapter↔App, NGINX↔App, App↔Postgres, and App↔the operator-provisioned MTProto transport. `telegram_database` and `telegram_migrate` join only App↔Postgres. Every Telegram network is `internal: true`; the app has no general outbound network. This is intentional: the current app uses a module-private MTProto transport boundary and direct Telegram egress is disabled. If a future in-process Telegram client needs direct egress, it must use a dedicated, firewall-restricted egress boundary that permits only Telegram endpoints; do not attach the app to `default`. Neither Telegram service has host ports.

The app receives trusted identity only from NGINX: `X-Ayaya-User-Id`, `X-Ayaya-User-Email`, `X-Ayaya-User-Display-Name`, `X-Ayaya-User-Role`, `X-Ayaya-Module-Key: telegram`, `X-Ayaya-Request-Id`, and `X-Ayaya-Identity-Signature`. Core computes the signature as lowercase hex `HMAC-SHA256(TELEGRAM_TRUSTED_IDENTITY_SECRET, user_id + "\\n" + module_key + "\\n" + email + "\\n" + display_name + "\\n" + role + "\\n" + request_id)`. Core and `telegram_app` receive the same non-empty `TELEGRAM_TRUSTED_IDENTITY_SECRET`; no other Telegram service needs it. NGINX must discard all client-provided `X-Ayaya-*` headers, use Core `auth_request`, capture the signature response header, and rebuild this exact allowlist. It also forwards only the browser request fields required by the UI, including `Sec-Fetch-Dest`, `Sec-Fetch-Mode`, `Sec-Fetch-Site`, and `Sec-Fetch-User`. Direct app access is unsupported and must not be published.

`TELEGRAM_MTPROTO_CLIENT_URL` and `TELEGRAM_MTPROTO_CLIENT_TOKEN` are mandatory production prerequisites for a live account connection. The URL names the private Telethon transport attached only to `ayaya_telegram_app_mtproto`; `http://telegram_mtproto:8081` is permitted solely for that Docker-internal hostname, otherwise production requires HTTPS. The root bundle includes this transport as a private service, not as a Telegram API emulator. It stores authenticated StringSessions only in encrypted form in its dedicated PostgreSQL database and has no published host port.

The transport must require `Authorization: Bearer <TELEGRAM_MTPROTO_CLIENT_TOKEN>` and expose these exact health contracts relative to the configured base URL:

- `GET /health/live` responds `200` with exactly `{ "status": "ok" }`.
- `GET /health/ready` responds `200` with exactly `{ "status": "ok", "ready": true, "contract": "opaque-session-handle.v1" }`.

All control endpoints are `POST` JSON endpoints relative to that base URL: `imports`, `state`, `operations/apply`, `auth/revoke`, `auth/phone`, `auth/code`, `auth/password`, `auth/qr`, and `auth/qr/poll`. Every request contains `account_id` and endpoint-specific fields. Operations requiring an authenticated account (`imports`, `state`, `operations/apply`, and `auth/revoke`) also require `session_handle`; authentication endpoints may omit it until authentication succeeds. A valid handle is exactly `opaque-session-handle-v1:` followed by at least 32 base64url characters (`[A-Za-z0-9_-]`). The transport must never accept or return plaintext `session` material. A successful `auth/*` response with `state: "authenticated"` returns `session_handle`, never `session`; the Rails app encrypts that opaque handle locally for later use. Every response is a JSON object; `imports` returns `state`, optional `cursor`, and boolean `complete`.

The transport must never log or persist handles, plaintext sessions, phone numbers, API hashes, login codes, 2FA passwords, or message text. Before enabling a live account, deployment must verify both `/health/live` and `/health/ready` with the bearer token. If the endpoint, TLS, token, liveness, or readiness contract is unavailable, the app fails closed with no test-client fallback; repair the private transport before enabling a live account.
