# Pic Obtainer module

This directory contains the Ayaya deployment descriptor for the independently
maintained Pic Obtainer module. The Python package, FastAPI application, worker,
migrations, and module adapter remain owned by the Pic Obtainer repository and
are not copied into Ayaya.

The module is registered under `pic_obtainer` and is available to Ayaya admins at
`/m/pic_obtainer`. Core communicates with the module only through the adapter
contract; module business logic and durable jobs remain outside Core.

Use [`compose.yml`](compose.yml) as the Ayaya deployment reference. Publish or
build a Pic Obtainer image first, then provide its name through
`PIC_OBTAINER_IMAGE`. The API service explicitly starts Uvicorn; the worker
service explicitly starts `pic-obtainer-worker`.

The descriptor includes a private PostgreSQL service and migration gate. Its
database is always `ayaya_mod_pic_obtainer`; application services do not start
until the `migrate` service completes successfully.

Required non-secret variables:

```text
PIC_OBTAINER_IMAGE
PIC_OBTAINER_DATABASE_URL
PIC_OBTAINER_MEDIA_ROOT
PIC_OBTAINER_MEDIA_HOST_PATH
PIC_OBTAINER_IMPORT_ROOT
PIC_OBTAINER_IMPORT_HOST_PATH
PIC_OBTAINER_AYAYA_ADAPTER_SECRET
```

Required worker-only secret variables:

```text
PIC_OBTAINER_RULE34_USER_ID
PIC_OBTAINER_RULE34_API_KEY
```

Optional worker variables are `PIC_OBTAINER_RULE34_API_BASE_URL`,
`PIC_OBTAINER_RULE34_REQUEST_LIMIT`, and
`PIC_OBTAINER_RULE34_REQUEST_WINDOW_SECONDS`.

When `PIC_OBTAINER_DATABASE_URL` is omitted, the descriptor uses its private
PostgreSQL service and the fixed internal development credential consistently.
Operators using an external database must provide a complete
`PIC_OBTAINER_DATABASE_URL` explicitly.

The adapter secret may be stored in a Docker secret or injected as an
environment variable. Do not commit its value. The Rule34 credentials must be
available only to `pic_obtainer_worker`; the API service must never receive
them.

The operator workflow is:

```bash
docker compose -f modules/pic_obtainer/compose.yml config
docker compose -f modules/pic_obtainer/compose.yml up -d pic_obtainer_api pic_obtainer_worker
curl -fsS http://pic_obtainer_api:8000/api/v1/health/live
```

The current application health route is `/api/v1/health/live`. After the Ayaya
adapter task is deployed, the platform contract route is
`/ayaya/health/live`, and Core status refreshes use the adapter route. In the
full Ayaya Compose network, health requests are made from an internal service
or through the Core status refresh flow. The media and import host directories
are persistent operator-managed data and must be backed up with the module
database. Roll back by stopping the two module services, restoring the previous
image and compatible database backup, then rerunning the explicit Alembic
migration before starting the services.
