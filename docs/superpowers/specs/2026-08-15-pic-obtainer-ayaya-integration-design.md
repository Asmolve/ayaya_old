# Pic Obtainer Ayaya Integration Design

## Status

Approved design direction: integrate `pic_obtainer` as an independent Ayaya module.

## Goal

Expose the existing `pic_obtainer` library and durable worker through an Ayaya-authenticated GUI at `/m/pic_obtainer`, while preserving `pic_obtainer` as an independently testable Python project.

## Scope

The first integration is an administrator-only module. Domain records remain global inside the module; this phase does not add Ayaya user ownership columns or multi-user data isolation.

The module will provide a GUI for:

- managing saved Rule34 searches;
- starting bounded Rule34 retrieval jobs;
- viewing snapshots and snapshot comparisons;
- submitting Pinterest export imports;
- requesting media downloads;
- viewing, polling, cancelling, and retrying durable jobs;
- inspecting module health and worker availability.

The following remain outside the first integration:

- Core-owned business logic for searches, imports, snapshots, or downloads;
- Core-owned job execution;
- multi-user ownership and per-user data isolation;
- dynamic NGINX configuration generation;
- WebSockets or a second queue system;
- storing provider credentials through the GUI.

## Architecture

`pic_obtainer` remains the module implementation and keeps its existing library-first boundaries:

```text
pic_obtainer API/GUI
    ├── application facade
    ├── PostgreSQL repositories and durable jobs
    └── local media storage

pic_obtainer worker
    └── Rule34, Pinterest, and media job handlers

Ayaya adapter surface
    └── manifest, liveness, readiness, and status
```

Ayaya remains the platform boundary:

```text
Browser
  -> NGINX /m/pic_obtainer
  -> Core auth_request
  -> pic_obtainer API/GUI
  -> pic_obtainer PostgreSQL job state
  -> pic_obtainer worker
```

The Core application communicates with the module only through the Ayaya adapter protocol. It does not import Python code, access the module database, or execute module jobs.

## Repository and deployment shape

The `pic_obtainer` repository becomes a complete Ayaya-compatible module by adding its module contract and platform adapter. Ayaya receives a module bundle/reference configuration that points to the independently maintained Python module image or build context.

The module deployment must provide:

- `pic_obtainer_api` for GUI and application API;
- `pic_obtainer_worker` for durable jobs;
- a PostgreSQL database dedicated to the module;
- a bind-mounted media directory;
- an adapter endpoint reachable only on the internal Compose network.

The API and worker must not publish host ports. User traffic reaches the API only through Ayaya NGINX. The worker receives provider credentials; the API/GUI does not.

## Ayaya module contract

The module key is `pic_obtainer`. The package manifest and runtime manifest use the same critical values:

```yaml
identity:
  module_key: pic_obtainer
  name: Pic Obtainer
  version: 0.1.0

protocol:
  adapter_protocol_version: "1.0"
  capabilities:
    - manifest.v1
    - health.v1
    - status.v1

presentation:
  description: Personal media discovery, preservation, and download service
  icon: images
  category: media

routes:
  ui_base_path: /m/pic_obtainer
  api_base_path: /m/pic_obtainer/api

access:
  default_policy: admin_only
```

The adapter requires `Authorization: Bearer <adapter-secret>` on every protocol endpoint. Secrets are compared securely and are never included in logs or status payloads.

The required protocol endpoints are:

```text
GET /ayaya/manifest
GET /ayaya/health/live
GET /ayaya/health/ready
GET /ayaya/status
```

`/ayaya/status` reports API, database, worker, and media-storage state. It may include a safe aggregate job summary, but must not expose credentials, absolute host paths, raw queries, or user-provided sensitive values.

## HTTP and GUI design

The existing versioned API remains the application boundary. GUI routes are thin and call the same facade used by the API; they must not duplicate repository or worker logic.

The initial screens are:

1. Dashboard — health, worker state, active jobs, and recent jobs.
2. Saved searches — create, edit, delete, and run Rule34 saved searches.
3. Snapshots — list retrieval results and open snapshot comparisons.
4. Imports — submit a local Pinterest export path and inspect its job.
5. Downloads — request media downloads and inspect storage incidents.
6. Jobs — inspect progress, cancel queued/running work, and retry failed work.

The first progress implementation uses polling of the existing job status endpoint. A job response must expose state, progress, diagnostics-safe error information, timestamps, and retry/cancellation state. Server-sent events or WebSockets are deferred.

The external route mapping is:

```text
/m/pic_obtainer                  GUI
/m/pic_obtainer/api               API prefix exposed through NGINX
/m/pic_obtainer/api/v1/...        Existing versioned application endpoints
```

The module must either configure FastAPI's root path correctly or mount routers so generated links and static assets work when served below `/m/pic_obtainer`.

## Ayaya identity and access

NGINX injects the trusted platform headers after successful Core authorization:

```text
X-Ayaya-User-Id
X-Ayaya-User-Email
X-Ayaya-User-Display-Name
X-Ayaya-User-Role
X-Ayaya-Module-Key
X-Ayaya-Request-Id
```

The module validates the module key and requires a non-empty trusted user id for browser/API requests. Direct API access must not be treated as authenticated merely because a caller supplied an `X-Ayaya-*` header; the deployment keeps the API internal and NGINX is the only public route.

For this phase, the module is registered with `admin_only`, and Core enforces that policy. No user id is persisted into domain records. The identity is still made available to request logging and audit context so the later multi-user phase can extend the same boundary.

## Configuration and secrets

The GUI may manage non-secret application values through a module-owned settings mechanism if required by the existing facade. Provider credentials remain worker-only environment variables or Docker secrets:

```text
PIC_OBTAINER_RULE34_API_BASE_URL
PIC_OBTAINER_RULE34_USER_ID
PIC_OBTAINER_RULE34_API_KEY
```

The API container must not receive the Rule34 API key. The adapter status and diagnostics must redact database URLs, API credentials, local absolute paths, and raw import/search payloads.

## Data and storage

The module keeps its existing PostgreSQL schema and durable job model. Ayaya supplies a distinct database name, for example `ayaya_mod_pic_obtainer`, without sharing Core tables.

Media binaries remain on the module-owned filesystem volume. The module exposes downloads through validated media references and never accepts arbitrary filesystem paths for file reads.

Pinterest imports are local artifacts. The first integration keeps the existing absolute-path command semantics and mounts the relevant import directory into the API/worker services according to deployment documentation; path access and archive limits remain enforced by `pic_obtainer`.

## Error handling

- Invalid user input returns the existing structured API error envelope.
- Adapter authentication failures return `401` without describing secret state.
- Unavailable database or worker state makes readiness/status fail safely.
- Durable job failures remain visible in job status without leaking credentials or raw payloads.
- Storage-full incidents remain module-owned and are surfaced in the GUI through existing storage incident endpoints.
- NGINX returns the platform's forbidden/unavailable responses for disabled, unhealthy, or unauthorized modules.

## Testing strategy

`pic_obtainer` tests must cover:

- manifest schema and critical field values;
- adapter bearer authentication;
- live/readiness/status behavior for API, database, worker, and media storage;
- trusted Ayaya header parsing and rejection of missing identity;
- GUI route mounting below `/m/pic_obtainer`;
- existing API operations remain facade-backed;
- job polling, cancellation, retry, and progress rendering;
- provider credentials absent from API service configuration;
- module Compose topology and internal-only ports.

`ayaya` tests must cover:

- registration of `pic_obtainer` from its adapter;
- `admin_only` access policy;
- static NGINX routing and trusted header injection;
- module readiness/status refresh;
- unavailable and forbidden behavior;
- contract comparison between package and runtime manifests.

## Implementation order

1. Add and test the Ayaya manifest/adapter surface in `pic_obtainer`.
2. Add trusted identity middleware and administrator-only deployment behavior.
3. Add GUI routes and templates over the existing facade/API.
4. Add the module Compose/deployment bundle and dedicated database/media configuration.
5. Connect the module to Ayaya NGINX and Core registration.
6. Run module contract, Python, Rails, Compose, and end-to-end checks.

## Acceptance criteria

The integration is ready for the first release when an Ayaya administrator can:

1. register and enable `pic_obtainer` from Core;
2. open `/m/pic_obtainer` through NGINX;
3. create a saved Rule34 search;
4. enqueue a retrieval job;
5. see job progress and final status;
6. inspect the resulting snapshot;
7. request a media download;
8. cancel or retry a job;
9. see a safe unavailable state when the worker or database is unhealthy;
10. verify that non-admin users cannot access the module and provider credentials are not exposed to the API container.
