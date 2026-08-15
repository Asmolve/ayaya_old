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

The adapter secret may be stored in a Docker secret or injected as an
environment variable. Do not commit its value. The Rule34 credentials must be
available only to `pic_obtainer_worker`; the API service must never receive
them.

The operator workflow is:

```bash
docker compose -f modules/pic_obtainer/compose.yml config
docker compose -f modules/pic_obtainer/compose.yml run --rm pic_obtainer_api alembic upgrade head
docker compose -f modules/pic_obtainer/compose.yml up -d pic_obtainer_api pic_obtainer_worker
curl -fsS http://pic_obtainer_api:8000/ayaya/health/live
```

In the full Ayaya Compose network, the health request is made from an internal
service or through the Core status refresh flow. The media and import host
directories are persistent operator-managed data and must be backed up with
the module database. Roll back by stopping the two module services, restoring
the previous image and compatible database backup, then rerunning the explicit
Alembic migration before starting the services.
