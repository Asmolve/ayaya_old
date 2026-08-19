# Planning Module

`planning` is Ayaya's personal priority planning module.

## Services

- `planning_app`: Rails module application for `/m/planning`
- `planning_adapter`: FastAPI Adapter Protocol service
- Database: `ayaya_mod_planning`
- Adapter internal port: `8080`

## Development

Run standalone bundle commands from the repository root:

```bash
docker compose --env-file .env -f modules/planning/compose.yml build planning_app planning_adapter
docker compose --env-file .env -f modules/planning/compose.yml run --rm planning_app bin/rails db:migrate
docker compose --env-file .env -f modules/planning/compose.yml up planning_app planning_adapter
```

The adapter reads `module.yml` through a read-only mount. Supply database credentials and all `PLANNING_*` secrets externally; do not bake secrets into either image.

Required environment values are `DATABASE_HOST`, `DATABASE_PORT`, `DATABASE_USERNAME`, `DATABASE_PASSWORD`, `PLANNING_DATABASE_NAME`, `PLANNING_SECRET_KEY_BASE`, `PLANNING_ADAPTER_SECRET`, and `PLANNING_INTERNAL_STATUS_SECRET`. The Compose bundle runs `planning_app` with `RAILS_ENV=production`; it supplies the internal adapter URL (`http://planning_app:3000/internal/ayaya/status`) and mounted manifest path (`/module/module.yml`) itself. Set `PLANNING_RAILS_MAX_THREADS` and `PLANNING_WEB_CONCURRENCY` only to override their production defaults.

The application entrypoint is boot-only and never runs schema changes. Run the explicit `db:migrate` command above during deployment before starting or replacing the application service.

## Deployment operations

Deploy in this order: build the two images, run the explicit migration command, start or replace `planning_app` and `planning_adapter`, then run the adapter readiness check below. The adapter is intentionally internal-only, so execute the check from its Compose service:

```bash
docker compose --env-file .env -f modules/planning/compose.yml exec -T planning_adapter python -c 'import os, urllib.request; request = urllib.request.Request("http://127.0.0.1:8080/ayaya/health/ready", headers={"Authorization": f"Bearer {os.environ[\"PLANNING_ADAPTER_SECRET\"]}"}); print(urllib.request.urlopen(request).read().decode())'
```

The command must print a JSON response with `"ready": true`. If it does not, leave the module disabled or unavailable until the Rails app and its database status are healthy; do not treat the adapter process merely being live as a successful deployment.

### Rollback

Code rollback and database rollback are separate operations. To roll back an unsuccessful release, stop or replace both Planning services with the previously deployed, compatible image versions, then rerun the readiness check. Do not automatically run `db:rollback`: use a down migration only when the release's migrations are explicitly reversible and the prior application version is compatible with the resulting schema. When database state must be restored, restore the last verified backup before returning traffic to the previous release.

### Persistent data, backups, and retention

Planning records live in the module PostgreSQL database (`ayaya_mod_planning`), which must be backed by persistent storage outside the application and adapter containers. Image replacement and code rollback must never remove that database or its storage. Take encrypted, access-controlled PostgreSQL backups before each migration and on a regular schedule; keep daily backups for 30 days and monthly backups for 12 months, or use a stricter organizational policy. Periodically restore a backup into an isolated database and verify it before relying on the retention policy. The module has no automatic deletion or archival policy for plans and plan items; retain application data until an operator applies an approved data-retention process.

## NGINX and trusted identity

Expose only the platform NGINX route for `/m/planning`; keep `planning_app` and its internal status route off public ports. NGINX must run Core `auth_request`, discard every client-supplied `X-Ayaya-*` header, and then inject only the identity headers derived from the successful Core response: `X-Ayaya-User-Id`, `X-Ayaya-User-Email`, `X-Ayaya-User-Display-Name`, `X-Ayaya-User-Role`, `X-Ayaya-Module-Key: planning`, and `X-Ayaya-Request-Id`.

The Planning app treats those headers as trusted only at that internal NGINX boundary. Direct requests must not be exposed publicly, because a direct client could otherwise forge the identity headers.

## Health and position routes

- `GET /internal/ayaya/status` is adapter-only. It requires `Authorization: Bearer <PLANNING_INTERNAL_STATUS_SECRET>` and reports the Rails app and database state.
- `PATCH /m/planning/plan_items/:id/position` accepts JSON `{ "priority": "now|next|later", "position": <non-negative integer> }` for the current Ayaya user. It returns the normalized item JSON, `422` with `{ "errors": [...] }` for invalid payloads, and `404` with `{ "error": "not_found" }` outside the owner scope.
- The workspace’s ordinary `PATCH /m/planning/plan_items/:id` forms remain the no-JavaScript fallback and use the same position normalization.
