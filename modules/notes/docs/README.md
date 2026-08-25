# Notes Module

`notes` is Ayaya's first reference module.

## Services

- `notes_app`: Rails Module App for `/m/notes`
- `notes_adapter`: FastAPI Adapter Protocol service
- Database: `ayaya_mod_notes`
- Adapter internal port: `8080`

## Development

Prepare the database explicitly:

```bash
docker compose run --rm notes_app bin/rails db:prepare
```

Start the platform:

```bash
docker compose up --build
```

Registration in Core is manual through the Rails runner service classes. Use [REGISTER.md](REGISTER.md) after the services are running; ActiveAdmin is only for enabling the registered module and adjusting access policy.

The Notes App and adapter are wired into the root Compose runtime. The adapter is intentionally not published to the host; Core reaches it over the Compose network at `http://notes_adapter:8080`.

## Bundle Runtime

The standalone module bundle compose file is `modules/notes/compose.yml`. It is a deployable shape for the module services, not the full local Ayaya platform runtime. The root `compose.yml` is the development runtime that wires Core, NGINX, PostgreSQL, `notes_app`, and `notes_adapter` together.

The adapter reads the package manifest from a read-only mount:

```yaml
./module.yml:/module/module.yml:ro
```

Required runtime environment:

- `DATABASE_HOST`
- `DATABASE_PORT`
- `DATABASE_USERNAME`
- `DATABASE_PASSWORD`
- `DATABASE_NAME`
- `NOTES_INTERNAL_STATUS_SECRET`
- `NOTES_ADAPTER_SECRET`
- `NOTES_APP_INTERNAL_STATUS_URL`
- `NOTES_MODULE_YML`
- `RAILS_MASTER_KEY` for production Rails app containers built from `modules/notes/app/Dockerfile`

Development images:

Run the standalone bundle commands from the repository root so they use the shared local `.env` file:

```bash
docker compose --env-file .env -f modules/notes/compose.yml build notes_app notes_adapter
docker compose --env-file .env -f modules/notes/compose.yml run --rm notes_app bin/rails db:prepare
docker compose --env-file .env -f modules/notes/compose.yml up notes_app notes_adapter
```

Production image examples:

```bash
docker build -t ayaya-notes-app ./modules/notes/app
docker build -t ayaya-notes-adapter ./modules/notes/adapter
```

Production run shape:

```yaml
services:
  notes_app:
    image: ayaya-notes-app
    environment:
      RAILS_MASTER_KEY: ${RAILS_MASTER_KEY}
      DATABASE_HOST: ${DATABASE_HOST}
      DATABASE_PORT: ${DATABASE_PORT:-5432}
      DATABASE_USERNAME: ${DATABASE_USERNAME}
      DATABASE_PASSWORD: ${DATABASE_PASSWORD}
      DATABASE_NAME: ayaya_mod_notes
      NOTES_INTERNAL_STATUS_SECRET: ${NOTES_INTERNAL_STATUS_SECRET}

  notes_adapter:
    image: ayaya-notes-adapter
    environment:
      NOTES_ADAPTER_SECRET: ${NOTES_ADAPTER_SECRET}
      NOTES_INTERNAL_STATUS_SECRET: ${NOTES_INTERNAL_STATUS_SECRET}
      NOTES_APP_INTERNAL_STATUS_URL: http://notes_app:3000/internal/ayaya/status
      NOTES_MODULE_YML: /module/module.yml
    volumes:
      - ./module.yml:/module/module.yml:ro
    depends_on:
      - notes_app
```

Attach both services to the same private network as Core, NGINX, and PostgreSQL. Publish only NGINX or the platform edge; keep `notes_app:3000` and `notes_adapter:8080` internal.

Run production containers with externally supplied secrets. Do not bake `RAILS_MASTER_KEY`, `NOTES_ADAPTER_SECRET`, database credentials, or `NOTES_INTERNAL_STATUS_SECRET` into images.

The Notes app persists state in PostgreSQL database `ayaya_mod_notes`. Back up and restore that database separately from Core. The adapter is stateless; rolling it back is replacing the adapter image and keeping the same mounted `module.yml` and secrets.

Rollback guidance:

- Roll back `notes_adapter` by redeploying the previous adapter image with the same `NOTES_ADAPTER_SECRET` and manifest mount.
- Roll back `notes_app` by redeploying the previous app image and verifying migrations are compatible with `ayaya_mod_notes`.
- If a database migration is not backward-compatible, restore `ayaya_mod_notes` from backup before starting the older app image.

## Smoke Test

Run this check with the platform services running:

1. Sign in to Core through `http://localhost:3000`.
2. Ensure `notes` is registered, healthy, enabled, and available to authenticated users. See [REGISTER.md](REGISTER.md) if registration or status refresh is needed.
3. Open `http://localhost:3000/m/notes`.
4. Create a note through the Notes UI.
5. Confirm the created note appears in the notes list.
6. Confirm direct internal app access without trusted `X-Ayaya-*` headers is rejected:

   ```bash
   docker compose exec nginx wget -S -O - http://notes_app:3000/m/notes
   ```

   Expected response: `401 Unauthorized`.

To verify the unauthenticated NGINX route from the host, run this without browser cookies:

```bash
curl -i http://127.0.0.1:3000/m/notes
```

Expected response: a redirect to Core login or an unauthorized response according to the Core authentication flow. Use the signed-in browser steps above to verify the authenticated `200 OK` Notes page.
