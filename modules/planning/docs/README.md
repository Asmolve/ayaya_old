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
docker compose --env-file .env -f modules/planning/compose.yml run --rm planning_app bin/rails db:prepare
docker compose --env-file .env -f modules/planning/compose.yml up planning_app planning_adapter
```

The adapter reads `module.yml` through a read-only mount. Supply database credentials and all `PLANNING_*` secrets externally; do not bake secrets into either image.

Required environment values are `DATABASE_HOST`, `DATABASE_PORT`, `DATABASE_USERNAME`, `DATABASE_PASSWORD`, `PLANNING_DATABASE_NAME`, `PLANNING_ADAPTER_SECRET`, and `PLANNING_INTERNAL_STATUS_SECRET`. The adapter also requires `PLANNING_APP_INTERNAL_STATUS_URL` and `PLANNING_MODULE_YML` when those defaults are not suitable for the deployment.

## Health and position routes

- `GET /internal/ayaya/status` is adapter-only. It requires `Authorization: Bearer <PLANNING_INTERNAL_STATUS_SECRET>` and reports the Rails app and database state.
- `PATCH /m/planning/plan_items/:id/position` accepts JSON `{ "priority": "now|next|later", "position": <non-negative integer> }` for the current Ayaya user. It returns the normalized item JSON, `422` with `{ "errors": [...] }` for invalid payloads, and `404` with `{ "error": "not_found" }` outside the owner scope.
- The workspace’s ordinary `PATCH /m/planning/plan_items/:id` forms remain the no-JavaScript fallback and use the same position normalization.
