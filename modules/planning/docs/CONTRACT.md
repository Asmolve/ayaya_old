# Planning Contract

Core communicates only with `planning_adapter`.

User traffic reaches `planning_app` through platform NGINX at `/m/planning`.

`planning_adapter` reads `/module/module.yml` as package truth and requires `Authorization: Bearer <PLANNING_ADAPTER_SECRET>`.

`planning_adapter` obtains runtime status from `planning_app` through `/internal/ayaya/status` using `PLANNING_INTERNAL_STATUS_SECRET`.
