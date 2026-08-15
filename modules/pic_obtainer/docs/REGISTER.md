# Register Pic Obtainer in Ayaya

1. Start the Ayaya Compose stack with the Pic Obtainer variables from `.env`.
   The module API is reachable internally at
   `http://pic_obtainer_api:8000` and is exposed to users only through
   `/m/pic_obtainer/`.
2. From the Ayaya Rails container, register the adapter through the existing
   Core service:

   ```ruby
   Modules::RegisterAdapter.call(
     adapter_url: "http://pic_obtainer_api:8000",
     adapter_secret: ENV.fetch("PIC_OBTAINER_AYAYA_ADAPTER_SECRET")
   )
   ```

   The registration service validates `/ayaya/manifest` and stores only a
   SHA-256 digest of the adapter secret.
3. In ActiveAdmin → Registered modules, refresh the manifest and status. Set
   access policy to `admin_only`, then enable the module only after runtime
   status is `healthy` or `degraded`.
4. Core's NGINX `auth_request` protects `/m/pic_obtainer/`, strips all
   client-supplied `X-Ayaya-*` headers, and injects the six trusted identity
   headers returned by Core.

If the adapter is unreachable or returns an incompatible manifest, Core keeps
the module unavailable. Re-run status refresh after correcting the API,
worker, database, or migration deployment.
