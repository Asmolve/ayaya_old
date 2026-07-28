# Ayaya

Ayaya is a Rails Core application for a modular personal productivity platform.

## Local Docker Runtime

Start Core, PostgreSQL, and NGINX:

```bash
docker compose up --build
```

Entrypoints:

- Platform NGINX: `http://localhost:8081`
- Direct Rails Core debugging: `http://localhost:3000`

The Compose runtime uses:

- `postgres` for the shared PostgreSQL instance;
- `core` for Rails Core;
- `nginx` for the platform routing and `auth_request` boundary.

The first reference module is expected to join the same Compose network as `notes_app` and own a separate database inside the shared PostgreSQL service.

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
