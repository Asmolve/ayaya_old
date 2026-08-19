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
