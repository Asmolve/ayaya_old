# Ayaya Core Foundation Notes

## ActiveAdmin

Core administration is available under `/admin`.

Only `User` records with `role = admin` can access ActiveAdmin.

## Module Registry

The foundation slice supports module records, access policy editing, manifest snapshots, and runtime status snapshots.

The local reference Notes module can be registered from the empty state on `/admin`, then refreshed and enabled from its ActiveAdmin resource page. The Notes module is already wired into the root Compose network; use [the Notes registration procedure](../modules/notes/docs/REGISTER.md) for the admin workflow and Rails runner commands as fallback diagnostics only.

## NGINX Static Routing

NGINX owns static module routing in v1.

Before proxying to a Module App, NGINX must call `/internal/auth/module_access` through `auth_request`.

NGINX must not trust incoming client-provided `X-Ayaya-*` headers. The example config sets platform headers from Core auth response values only.

The example config is a standalone NGINX configuration for direct `nginx -t -c` validation. The Module App route keeps `proxy_pass_request_headers off` and explicitly restores an allowlist of normal request headers (`Host`, forwarding and client identity headers, `Cookie`, `Authorization`, content negotiation, browser metadata, CSRF, and request ID) plus exactly the six auth-derived `X-Ayaya-*` headers. This prevents arbitrary client `X-Ayaya-*` headers from reaching a Module App while preserving normal application requests.

The example config is mounted by `compose.yml` into the local NGINX container. The `notes_app` upstream is resolved lazily so NGINX can boot before the reference Notes module exists.

Module App ports must remain internal and must not be publicly exposed.

## Docker Development Runtime

Local development has a Docker Compose runtime for the platform and the Notes reference module:

- `postgres` runs the shared PostgreSQL instance.
- `core` runs the Rails Core application with `DATABASE_HOST=postgres`.
- `notes_app` runs the Notes Module App with `DATABASE_NAME=ayaya_mod_notes`.
- `notes_adapter` exposes the Notes Adapter Protocol endpoints to Core on the internal Compose network.
- `nginx` exposes the platform entry point on `http://localhost:3000`.

Prepare the Notes database explicitly:

```bash
docker compose run --rm notes_app bin/rails db:prepare
```

Use `docker compose up --build` to start the runtime.

Core is also published directly on `http://localhost:3000` for Rails-only debugging. User traffic validation should use the NGINX entry point because NGINX owns `auth_request` and trusted header injection.

The PostgreSQL container creates the Core development database. The Notes reference module uses its own `ayaya_mod_notes` database in the same PostgreSQL service. Future modules should receive their own separate database unless a module has a documented reason to own a dedicated database service.

Module App and adapter ports are internal-only and are not published to the host. Core communicates with Notes through `http://notes_adapter:8080`; user traffic reaches Notes through NGINX at `/m/notes`.

## Foundation Verification

The foundation slice is complete when:

- Rails tests pass.
- Devise routes exist.
- ActiveAdmin routes exist.
- `/internal/auth/module_access` exists.
- Module registry models enforce valid states and access policy.
- Adapter manifest validation rejects invalid module keys and missing required capabilities.
- Adapter client sends `Authorization: Bearer <adapter_secret>`.
- Contract runner compares critical fields between `module.yml` and runtime manifest.
- Static NGINX example documents `auth_request` and trusted header injection.
