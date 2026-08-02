# Ayaya

Ayaya is a Rails Core application for a modular personal productivity platform.

## Local Docker Runtime

Prepare the Notes database explicitly before starting the platform:

```bash
docker compose run --rm notes_app bin/rails db:prepare
```

Start Core, PostgreSQL, the Notes reference module, and NGINX:

```bash
docker compose up --build
```

Entrypoints:

- Platform NGINX: `http://localhost:3000`
- Direct Rails Core debugging: `http://localhost:3001`

The Compose runtime uses:

- `postgres` for the shared PostgreSQL instance;
- `core` for Rails Core;
- `notes_app` and `notes_adapter` for the wired Notes reference module;
- `nginx` for the platform routing and `auth_request` boundary.

Notes owns the separate `ayaya_mod_notes` database inside the shared PostgreSQL service. Register the module manually in Core using the procedure in [modules/notes/docs/REGISTER.md](modules/notes/docs/REGISTER.md).

Module App and adapter ports remain internal to the Compose network. The adapter is not published to the host; Core reaches it at `http://notes_adapter:8080`.

## Local Rails Runtime

The app can still run directly on the host when PostgreSQL is available locally:

```bash
bin/setup --skip-server
bin/rails server
```

Run the test suite:

```bash
bin/rails test
```
