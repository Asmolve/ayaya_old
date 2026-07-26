# Ayaya Module Contract v1

This document defines the required contract for modules compatible with Ayaya v1.

## 1. Module Definition

A module is a standalone application integrated with Ayaya through a mandatory adapter.

Each module has:

- one stable `module_key`;
- one Module App;
- one Adapter;
- one module database;
- one module bundle;
- one runtime manifest exposed by the Adapter.

Core communicates only with the Adapter. Users access the Module App through platform NGINX.

## 2. Module Key

`module_key` must use `snake_case`.

Validation pattern:

```text
^[a-z][a-z0-9_]*[a-z0-9]$
```

Examples:

```text
notes
shopping_list
anime_tracker
finance_calendar
```

The module key is immutable after registration.

The module key is used consistently:

```text
URL route:       /m/notes
Database:        ayaya_mod_notes
App service:     notes_app
Adapter service: notes_adapter
Namespace:       notes.<capability>
```

## 3. Module Bundle

Each module must be delivered as a standardized bundle.

Minimum structure:

```text
modules/<module_key>/
  module.yml
  compose.yml
  adapter/
  app/
  docs/
    README.md
    CONTRACT.md
```

Optional structure:

```text
  db/
    migrations/
    seeds/
  tests/
    contract/
  deploy/
    nginx.conf
```

The bundle is the source artifact for development, review, and deployment. Core does not read bundle files at runtime.

## 4. Module Manifest

`module.yml` and `GET /ayaya/manifest` must use the same schema.

Core treats the Adapter API as runtime truth. `module.yml` is package truth.

Minimum manifest:

```yaml
identity:
  module_key: notes
  name: Notes
  version: 0.1.0

protocol:
  adapter_protocol_version: "1.0"
  capabilities:
    - manifest.v1
    - health.v1
    - status.v1

presentation:
  description: Personal notes module
  icon: file-text
  category: productivity

routes:
  ui_base_path: /m/notes
  api_base_path: /m/notes/api

access:
  default_policy: authenticated
```

Required sections:

- `identity`;
- `protocol`;
- `routes`;
- `access`.

Optional section:

- `presentation`.

`identity.name` is required and is the fallback display name if presentation metadata is absent.

## 5. Manifest Fields

### `identity`

Required:

- `module_key`: stable snake_case identifier;
- `name`: human-readable module name;
- `version`: module version.

### `protocol`

Required:

- `adapter_protocol_version`;
- `capabilities`.

Required v1 capabilities:

```yaml
- manifest.v1
- health.v1
- status.v1
```

Optional future capabilities may include:

```yaml
- jobs.status.v1
- jobs.control.v1
- service_access.declaration.v1
- events.declaration.v1
- integrations.declaration.v1
- lifecycle.notify.v1
```

Capabilities must describe real implemented behavior.

### `presentation`

Optional:

- `description`;
- `icon`;
- `category`;
- `docs_url`.

Core must not require presentation metadata except for `identity.name`.

### `routes`

Required:

- `ui_base_path`;
- `api_base_path`.

Routes must be under the module namespace:

```text
/m/<module_key>
/m/<module_key>/api
```

For `notes`:

```text
/m/notes
/m/notes/api
```

Core stores route metadata but does not configure NGINX in v1.

### `access`

Required:

- `default_policy`.

Allowed values:

- `authenticated`;
- `admin_only`;
- `manual`.

This is only an initial registration default. Core owns actual runtime access policy after registration.

## 6. Adapter Protocol

Adapter Protocol v1 is read-only.

Required endpoints:

```text
GET /ayaya/manifest
GET /ayaya/health/live
GET /ayaya/health/ready
GET /ayaya/status
```

Every endpoint must require the per-adapter shared secret from Core.

Recommended authentication header:

```text
Authorization: Bearer <adapter_secret>
```

The adapter must reject missing or invalid secrets.

Secrets must not be logged.

## 7. `GET /ayaya/manifest`

Returns the runtime manifest.

The response must match the schema used by `module.yml`.

Critical fields must match `module.yml`:

- `identity.module_key`;
- `identity.name`;
- `identity.version`;
- `protocol.adapter_protocol_version`;
- `protocol.capabilities`;
- `routes`;
- `access.default_policy`.

## 8. `GET /ayaya/health/live`

Checks whether the Adapter process is alive.

Example response:

```json
{
  "status": "ok",
  "component": "adapter"
}
```

Live does not prove that the module is usable.

## 9. `GET /ayaya/health/ready`

Checks whether the Adapter is ready to serve Core control-plane requests.

Example response:

```json
{
  "status": "ok",
  "component": "adapter",
  "ready": true
}
```

Readiness must fail if the adapter cannot provide required manifest/status behavior.

## 10. `GET /ayaya/status`

Returns a summary of module runtime status.

Minimum response:

```json
{
  "runtime_status": "healthy",
  "module_key": "notes",
  "module_version": "0.1.0",
  "adapter_protocol_version": "1.0",
  "checked_at": "2026-07-27T12:00:00Z",
  "components": {
    "adapter": "healthy",
    "app": "healthy",
    "database": "healthy"
  },
  "degraded_reasons": []
}
```

Allowed runtime statuses:

- `healthy`;
- `degraded`;
- `unhealthy`;
- `unreachable`;
- `incompatible`.

`degraded` means the primary user path still works, but a non-critical component is impaired.

If the module database is unavailable, the module should report `unhealthy`, not `degraded`.

## 11. NGINX Routing

NGINX routes are static in v1.

The module bundle must document required NGINX route configuration.

User traffic must pass through NGINX and Core `auth_request` before reaching the Module App.

Module App ports must not be publicly exposed.

NGINX must strip incoming `X-Ayaya-*` headers and set platform-trusted headers itself.

## 12. Trusted Identity Headers

Modules receive identity through headers injected by NGINX:

```text
X-Ayaya-User-Id
X-Ayaya-User-Email
X-Ayaya-User-Display-Name
X-Ayaya-User-Role
X-Ayaya-Module-Key
X-Ayaya-Request-Id
```

Modules must not trust these headers from public clients.

Modules must use `X-Ayaya-User-Id` as the stable identity value.

`X-Ayaya-User-Display-Name` is for presentation only.

## 13. Local Users

Modules should maintain lazy local user records when useful.

Recommended local user fields:

- `core_user_id`;
- `email`;
- `display_name`;
- `global_role`;
- `last_seen_at`.

The local user record is a cache/snapshot. Core remains the source of truth.

Modules must not use email as the stable user identifier.

## 14. Module Authorization

Core controls access to the module route.

The module controls access to domain actions and records.

Modules must not assume that platform admin access automatically grants every domain permission unless that rule is explicitly implemented inside the module.

For the `notes` reference module:

- each note belongs to a local module user;
- users can view and mutate only their own notes;
- local authorization is enforced by the module, not Core.

## 15. Database

Each module owns a separate database inside the shared PostgreSQL instance.

Database naming convention:

```text
ayaya_mod_<module_key>
```

Examples:

```text
ayaya_mod_notes
ayaya_mod_shopping_list
```

Modules own migrations and schema.

Core must not connect to module databases.

Modules must not connect to Core or other module databases.

## 16. Deployment Metadata

The module bundle must document:

- build command;
- start command;
- migration command;
- healthcheck command;
- rollback notes;
- persistent/shared files or volumes;
- required environment variables;
- required secrets;
- database name;
- exposed internal service ports;
- NGINX route requirements.

Automatic migrations on application start are forbidden or strongly discouraged.

Migrations should be explicit deploy steps.

## 17. Background Jobs

Modules own their own background jobs.

Core does not run module jobs.

If a module has background jobs, its adapter status may include job summary metadata.

Job control through Core is not required in v1.

## 18. External Integrations

Modules own their external integrations in v1.

The module bundle must document required provider secrets, scopes, callback routes, and operational notes.

Core does not store shared OAuth tokens in v1.

## 19. Events And Service Access

Runtime events are out of scope for v1.

Service-to-service runtime calls are out of scope for v1.

Modules may include future declaration placeholders only if they do not imply runtime support.

Direct calls to another module's private internal service or database are forbidden.

Future module communication must use declared APIs or versioned events through platform-approved boundaries.

## 20. Contract Tests

Every module must provide or pass contract tests before registration or update.

Contract tests must verify:

- `module.yml` schema;
- Adapter manifest schema;
- critical field equality between `module.yml` and `GET /ayaya/manifest`;
- required adapter endpoints;
- adapter shared secret enforcement;
- health response formats;
- status response format;
- capability declarations;
- route metadata;
- access default validity;
- module key validity;
- no public exposure of Module App ports;
- no documented dependency on Core DB access;
- no documented dependency on other module DB access.

The expected future command shape is:

```text
ayaya-contract test --module-yml module.yml --adapter-url http://notes_adapter:8080
```

The exact tool implementation is not required before the contract is documented, but compatibility must remain mechanically testable.

