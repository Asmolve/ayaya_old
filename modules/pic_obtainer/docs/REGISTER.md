# Register Pic Obtainer in Ayaya

1. Configure the Pic Obtainer variables in `.env`, including
   `PIC_OBTAINER_ADAPTER_URL=http://pic_obtainer_api:8000`, then start the
   Compose services:

   ```sh
   docker compose up -d
   ```

   The module API is reachable internally at `http://pic_obtainer_api:8000`
   and is exposed to users only through `/m/pic_obtainer/`.
2. Open `/admin` and click **Register Pic Obtainer**.
3. In ActiveAdmin → Registered modules, refresh the manifest and status. Set
   access policy to `admin_only`, then enable the module only after runtime
   status is `healthy` or `degraded`.
4. Core's NGINX `auth_request` protects `/m/pic_obtainer/`, strips all
   client-supplied `X-Ayaya-*` headers, and injects the six trusted identity
   headers returned by Core.

## Diagnostic fallback

If the ActiveAdmin registration action is unavailable or needs diagnosis, run
the existing Core registration service from the Ayaya Rails container:

   ```sh
   docker compose exec core bin/rails runner 'Modules::RegisterAdapter.call(
     adapter_url: ENV.fetch("PIC_OBTAINER_ADAPTER_URL"),
     adapter_secret: ENV.fetch("PIC_OBTAINER_AYAYA_ADAPTER_SECRET")
   )'
   ```

The registration service validates `/ayaya/manifest` and stores only a
SHA-256 digest of the adapter secret.

If the adapter is unreachable or returns an incompatible manifest, Core keeps
the module unavailable. Re-run status refresh after correcting the API,
worker, database, or migration deployment.

For a live smoke check, set `AYAYA_E2E_BASE_URL` and an operator
`AYAYA_E2E_COOKIE`, then run Pic Obtainer's opt-in deployment test. The test is
skipped without those environment variables.
