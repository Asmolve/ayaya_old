# Planning Contract

Core communicates only with `planning_adapter`.

User traffic reaches `planning_app` through platform NGINX at `/m/planning`.

`planning_adapter` reads `/module/module.yml` as package truth and requires `Authorization: Bearer <PLANNING_ADAPTER_SECRET>`.

`planning_adapter` obtains runtime status from `planning_app` through `/internal/ayaya/status` using `PLANNING_INTERNAL_STATUS_SECRET`.

The app status endpoint is not user-facing: it requires the internal bearer secret and verifies the module database with `SELECT 1`. It returns `503` with `runtime_status: unhealthy` and `components.database: unhealthy` when that check fails. The adapter only reports ready when the app runtime and database are both healthy.

Priority-map JSON moves use `PATCH /m/planning/plan_items/:id/position` with `{ priority, position }`. The Rails app scopes the item through the current local user, normalizes every lane in a transaction, and returns JSON errors for malformed values. HTML move controls use the item update route as a functional no-JavaScript fallback.
