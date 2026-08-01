# Reference Notes Module Design

## Purpose

The `notes` module is the first reference Ayaya module. Its primary purpose is to validate the module architecture with a real user-facing application, not to become a feature-rich notes product.

The module must prove that an independently owned application can run behind Ayaya's Core, NGINX, Adapter Protocol, trusted headers, and separate database boundaries.

## Scope

The first `notes` slice includes:

- note listing;
- note creation;
- note viewing;
- note editing;
- note deletion;
- note ownership by local module user;
- lazy local user creation and refresh from trusted `X-Ayaya-*` headers;
- direct request rejection when required trusted headers are missing;
- a protected internal module status endpoint;
- a FastAPI adapter implementing Adapter Protocol v1;
- root Compose integration for one-command local runtime;
- explicit database preparation and migrations;
- contract-oriented tests that verify the module boundary.

The first slice excludes:

- tags;
- search;
- markdown editor;
- rich text;
- sharing;
- attachments;
- background jobs;
- a public notes API;
- automatic registration in Core;
- automatic migrations on application start;
- dynamic NGINX config generation.

## Module Bundle

The module lives inside the monorepo but must be structured as an independent bundle:

```text
modules/notes/
  module.yml
  compose.yml
  app/
  adapter/
  docs/
    README.md
    CONTRACT.md
```

`modules/notes/app` is a standalone Rails application for module UI and domain behavior.

`modules/notes/adapter` is a standalone FastAPI service for Core control-plane communication.

`modules/notes/module.yml` is package truth for module metadata. Core does not read this file at runtime.

## Architecture

`notes_app` owns:

- UI routes under `/m/notes`;
- note domain models;
- local module user records;
- domain authorization;
- module database access;
- module migrations;
- internal runtime status computation.

`notes_adapter` owns:

- Adapter Protocol v1 endpoints;
- adapter shared secret enforcement;
- runtime manifest exposure from `module.yml`;
- live/readiness checks for adapter control-plane behavior;
- status translation from `notes_app` internal status into Adapter Protocol format.

Core owns:

- global identity;
- web sessions;
- platform module access policy;
- module registry;
- manifest and status snapshots;
- ActiveAdmin registration and enablement.

NGINX owns:

- public routing to `/m/notes`;
- Core `auth_request` calls;
- trusted header injection;
- stripping untrusted client-provided `X-Ayaya-*` headers.

## Traffic

User traffic:

```text
Browser -> NGINX /m/notes -> Core auth_request -> notes_app
```

Control-plane traffic:

```text
Core -> notes_adapter -> notes_app internal status
```

Core must not call `notes_app` directly.

The adapter must not proxy user traffic.

User traffic must not pass through the adapter.

## Manifest

`module.yml` and `GET /ayaya/manifest` use the same schema.

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
  description: Personal notes
  icon: file-text
  category: productivity

routes:
  ui_base_path: /m/notes
  api_base_path: /m/notes/api

access:
  default_policy: authenticated
```

`notes_adapter` reads `module.yml` instead of duplicating manifest values in Python constants.

Critical fields in runtime manifest must match `module.yml` exactly:

- `identity.module_key`;
- `identity.name`;
- `identity.version`;
- `protocol.adapter_protocol_version`;
- `protocol.capabilities`;
- `routes`;
- `access.default_policy`.

## Adapter Protocol

`notes_adapter` implements these endpoints:

```text
GET /ayaya/manifest
GET /ayaya/health/live
GET /ayaya/health/ready
GET /ayaya/status
```

Every adapter endpoint requires:

```text
Authorization: Bearer <NOTES_ADAPTER_SECRET>
```

Missing or invalid adapter secret returns `401 Unauthorized`.

Adapter secrets must not be logged.

`/ayaya/manifest` returns the parsed `module.yml`.

`/ayaya/health/live` returns whether the adapter process is alive.

`/ayaya/health/ready` returns ready only when the adapter can read a valid manifest and reach `notes_app` internal status.

`/ayaya/status` calls `notes_app` internal status and converts it to Adapter Protocol v1 status shape.

## Notes App Identity

`notes_app` accepts user identity only from trusted headers injected by NGINX:

```text
X-Ayaya-User-Id
X-Ayaya-User-Email
X-Ayaya-User-Display-Name
X-Ayaya-User-Role
X-Ayaya-Module-Key
X-Ayaya-Request-Id
```

Required headers:

- `X-Ayaya-User-Id`;
- `X-Ayaya-Module-Key`.

If `X-Ayaya-User-Id` is missing, `notes_app` returns `401 Unauthorized`.

If `X-Ayaya-Module-Key` is not `notes`, `notes_app` returns `401 Unauthorized`.

`X-Ayaya-User-Id` is the stable identity value.

`X-Ayaya-User-Email`, `X-Ayaya-User-Display-Name`, and `X-Ayaya-User-Role` are copied into the local user record as mutable snapshot fields when present.

`notes_app` does not verify cryptographic signatures for these headers in v1. Trust is provided by the NGINX and internal network boundary.

## Local Users

`notes_app` maintains lazy local user records.

Recommended table fields:

- `core_user_id`;
- `email`;
- `display_name`;
- `global_role`;
- `last_seen_at`.

On each valid request, `notes_app` finds or creates the local user by `core_user_id`, refreshes snapshot fields when present, and updates `last_seen_at`.

Email and display name must not be used as stable identifiers.

## Notes Domain

Each note belongs to one local user.

Minimum note fields:

- `local_user_id`;
- `title`;
- `body`;
- `created_at`;
- `updated_at`.

Users can list, view, create, edit, and delete only their own notes.

Core admins do not automatically receive cross-user note access unless the module explicitly implements that behavior. The first slice does not implement admin domain override.

## Internal Status Endpoint

`notes_app` exposes an internal status endpoint for `notes_adapter`.

Recommended path:

```text
GET /internal/ayaya/status
```

This endpoint requires:

```text
Authorization: Bearer <NOTES_INTERNAL_STATUS_SECRET>
```

Missing or invalid internal status secret returns `401 Unauthorized`.

The endpoint reports app and database health in a module-local shape that the adapter converts to Adapter Protocol v1.

The endpoint is not part of the public module UI and must not be routed publicly by NGINX.

## Database

`notes_app` owns a separate PostgreSQL database inside the shared local PostgreSQL service:

```text
ayaya_mod_notes
```

Core must not connect to `ayaya_mod_notes`.

`notes_adapter` must not connect to `ayaya_mod_notes` in the first slice. It obtains runtime status from `notes_app`.

`notes_app` owns its migrations and schema.

Migrations are explicit:

```bash
docker compose run --rm notes_app bin/rails db:prepare
```

Automatic migrations on `notes_app` startup are forbidden for the reference module.

## Compose Integration

Root `compose.yml` includes:

```text
postgres
core
nginx
notes_app
notes_adapter
```

`notes_app` and `notes_adapter` are internal services. Their ports must not be published to the host for normal user traffic.

The local runtime target remains:

```bash
docker compose up --build
```

Before first module use, the developer prepares the module database explicitly:

```bash
docker compose run --rm notes_app bin/rails db:prepare
```

`modules/notes/compose.yml` exists as a module bundle artifact documenting module-owned services and commands. Root Compose is the development orchestration entry point for this repository.

## NGINX

Root NGINX config includes static routing for `/m/notes`.

For `/m/notes`, NGINX must:

- call Core `/internal/auth/module_access` through `auth_request`;
- strip client-provided `X-Ayaya-*` headers;
- forward only an explicit allowlist of normal request headers;
- set exactly the trusted `X-Ayaya-*` headers from Core auth response;
- proxy user traffic to `notes_app`.

NGINX must not route `/internal/ayaya/status` publicly.

## Registration

Registration is manual in v1.

Expected development flow:

1. Build and start platform services.
2. Prepare `ayaya_mod_notes`.
3. Run module app tests.
4. Run adapter tests.
5. Run contract tests against `module.yml` and live adapter.
6. Register `notes_adapter` URL in Core.
7. Enable `notes` through Core admin.
8. Validate `/m/notes` through NGINX.

Core registration does not create the module database, run module migrations, deploy containers, or modify NGINX.

## Testing Requirements

`notes_app` tests must cover:

- missing trusted headers reject user traffic;
- wrong `X-Ayaya-Module-Key` rejects user traffic;
- lazy local user creation from trusted headers;
- local user snapshot refresh;
- note listing scoped to current local user;
- note viewing scoped to current local user;
- note creation ownership;
- note editing ownership;
- note deletion ownership;
- internal status endpoint requires internal secret;
- internal status reports database availability.

`notes_adapter` tests must cover:

- all Adapter Protocol endpoints require adapter secret;
- manifest endpoint returns `module.yml`;
- live endpoint shape;
- ready endpoint shape;
- status endpoint calls `notes_app` internal status with internal secret;
- status endpoint maps healthy app/database status to Adapter Protocol `healthy`;
- status endpoint maps app or database failure to Adapter Protocol `unhealthy` or `unreachable`.

Contract tests must cover:

- `module.yml` schema;
- runtime manifest schema;
- critical field equality between `module.yml` and runtime manifest;
- required adapter endpoints;
- adapter shared secret enforcement;
- health response formats;
- status response format;
- route metadata;
- module key validity;
- no public exposure of module app ports in root Compose;
- no documented dependency on Core database access.

System or smoke tests must cover:

- `/m/notes` is accessible through NGINX after Core authorization;
- direct module app request without trusted headers fails;
- a user cannot see another user's notes.

## Operational Notes

The first slice uses simple development secrets in Compose. Production-grade secret management is out of scope for this slice.

The first slice does not introduce a module deployer.

The first slice does not introduce module-to-module communication.

The first slice may require local documentation updates in:

- `README.md`;
- `docs/core_foundation.md`;
- `modules/notes/docs/README.md`;
- `modules/notes/docs/CONTRACT.md`.

## Acceptance Criteria

The design is complete when:

- `notes_app` is a standalone Rails app under `modules/notes/app`;
- `notes_adapter` is a standalone FastAPI app under `modules/notes/adapter`;
- `module.yml` defines the `notes` manifest;
- root Compose starts Core, NGINX, PostgreSQL, `notes_app`, and `notes_adapter`;
- `ayaya_mod_notes` is prepared by an explicit command;
- Core can register and refresh `notes` through `notes_adapter`;
- `/m/notes` works only through NGINX-authenticated traffic;
- direct traffic without trusted headers is rejected;
- each user can access only their own notes;
- app, adapter, contract, and NGINX smoke checks pass.
