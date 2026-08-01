# Notes Contract

Core communicates only with `notes_adapter`.

User traffic reaches `notes_app` only through platform NGINX at `/m/notes`.

`notes_app` requires `X-Ayaya-User-Id` and `X-Ayaya-Module-Key: notes`.

`notes_adapter` reads `../module.yml` as package truth and requires `Authorization: Bearer <NOTES_ADAPTER_SECRET>`.

`notes_adapter` obtains runtime status from `notes_app` through `/internal/ayaya/status` using `NOTES_INTERNAL_STATUS_SECRET`.
