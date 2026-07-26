# Ayaya Architecture Constitution

This document defines the non-negotiable architectural rules for Ayaya. It exists to protect module independence, keep Core bounded, and make future module work mechanically reviewable.

## 1. Core Boundary

Core owns identity, sessions, module registry, module access policy, and platform administration.

Core must not own module business logic, module domain data, module-local authorization rules, module background jobs, or module external integrations.

Rails is an implementation choice for Core, not a reason to absorb modules into Core.

## 2. Module Boundary

A module is an independently deployable application with its own backend, frontend, adapter, and database.

Modules own their domain models, domain authorization, migrations, background jobs, and external integrations.

Modules must not access Core tables directly.

Modules must not access another module's database directly.

## 3. Adapter Boundary

Core communicates with modules only through their adapters.

Core must never call a Module App directly.

The adapter is a control-plane bridge, not a user-traffic proxy and not a place for module business logic.

Adapter Protocol v1 is read-only from Core's perspective. Core may call manifest, health, readiness, and status endpoints. Core must not require adapters to start, stop, restart, migrate, enable, disable, or deploy modules in v1.

## 4. User Traffic Boundary

User traffic flows through platform NGINX directly to Module Apps.

```text
Browser -> NGINX -> Core auth_request
Browser -> NGINX -> Module App
```

User traffic does not flow through Core as an application proxy and does not flow through Adapter.

NGINX routing is static in v1. Core is not an NGINX config manager.

## 5. Authentication Model

Ayaya v1 uses web-first session authentication.

Users authenticate through Core. Core stores server-side session state and the browser stores a secure session cookie.

NGINX uses `auth_request` to ask Core whether a request may access a module route.

JWS/JWT is not the primary browser authentication mechanism in v1. Signed tokens may be introduced later for service or API flows.

## 6. Trusted Headers

Modules receive platform identity through trusted headers injected by NGINX after successful Core authorization.

Version 1 identity headers are:

```text
X-Ayaya-User-Id
X-Ayaya-User-Email
X-Ayaya-User-Display-Name
X-Ayaya-User-Role
X-Ayaya-Module-Key
X-Ayaya-Request-Id
```

NGINX must strip all incoming `X-Ayaya-*` headers from client requests before setting platform headers.

Module services must not be publicly reachable. A module may trust `X-Ayaya-*` headers only when traffic arrives through platform NGINX and the internal network boundary.

`display_name` is a presentation field, not an authorization field.

## 7. Authorization Ownership

Core owns platform access to modules.

Modules own domain authorization inside their own application.

Core can decide whether a user may open `notes`. The `notes` module decides whether that user may read, edit, or delete a specific note.

Core admins automatically pass the platform access gate for all enabled modules, subject to runtime status. That does not automatically grant all domain permissions inside every module unless a module explicitly implements that behavior.

## 8. Core User Model

Core has one persisted identity model: `User`.

Supported global roles in v1:

- `user`;
- `admin`.

`Guest` is not a persisted role. It means no authenticated user.

Users are not physically deleted in v1. Core supports deactivation. Inactive users cannot log in or pass module access checks.

## 9. Module User Model

Modules may maintain lazy local user records.

Local module users are snapshots of Core users, not the source of truth.

Recommended local fields:

- `core_user_id`;
- `email`;
- `display_name`;
- `global_role`;
- `last_seen_at`.

Modules must use `core_user_id` as the stable identity link. Email and display name may change.

## 10. Module Registry

Core has an explicit module registry in its own database.

Admin registration flow in v1:

1. An admin provides `adapter_url` and `adapter_secret`.
2. Core calls the adapter manifest endpoint.
3. Core validates protocol version and required fields.
4. Core stores a module record and manifest snapshot.
5. The module starts in a registered or disabled state.
6. An admin explicitly enables the module.

Registration does not deploy containers, create databases, run migrations, or modify NGINX.

## 11. Manifest Truth

Runtime truth for Core is the Adapter API.

Package truth for development and review is `module.yml`.

Core must not read module source files or bundle manifests during runtime registration.

`module.yml` and `GET /ayaya/manifest` must use the same schema and match on critical fields. Contract tests enforce this.

## 12. Manifest Snapshot And Refresh

Core stores the latest valid manifest snapshot.

The adapter remains the source for manifest refresh, health, readiness, runtime status, and compatibility checks.

Manifest refresh is a compatibility event. Core must not silently accept breaking manifest changes.

Refresh must not silently overwrite admin-managed access policy.

## 13. Module State Model

Module state has two independent axes.

Admin state:

- `registered`;
- `enabled`;
- `disabled`;
- `maintenance`.

Runtime status:

- `unknown`;
- `healthy`;
- `degraded`;
- `unhealthy`;
- `unreachable`;
- `incompatible`.

Admin state is controlled by Core/admin actions.

Runtime status is derived from Adapter manifest, health, readiness, and status checks.

User access is allowed only when `admin_state = enabled` and runtime status is `healthy` or `degraded`.

`unknown`, `unhealthy`, `unreachable`, and `incompatible` block user access by default.

## 14. Module Access Policy

Manifest access defaults are registration defaults only.

Core owns the actual module access policy.

Supported v1 access modes:

- `authenticated`: any active logged-in user;
- `admin_only`: Core admins only;
- `manual`: users explicitly allowlisted in Core, plus Core admins.

Changing a module's manifest default access policy must not override existing Core admin decisions.

## 15. Database Ownership

Core has its own database.

Each module has a separate database inside the shared PostgreSQL instance in v1.

Example:

```text
ayaya_core
ayaya_mod_notes
ayaya_mod_shopping_list
```

Core does not run module migrations and does not inspect module schemas.

Modules own their migrations, seeds, backup notes, and data retention behavior.

## 16. Deployment Discipline

Core is not a deployer in v1.

Module deployment follows a Capistrano-like discipline as a contract, not as a platform feature:

```text
prepare -> build -> migrate -> start -> healthcheck -> register/refresh -> enable
```

Module bundles must document:

- build command;
- start command;
- migration command;
- healthcheck command;
- rollback notes;
- persistent/shared data;
- required environment variables and secrets.

Automatic migrations at application start are forbidden or strongly discouraged. Migrations should be explicit deployment steps.

Rollback of code and rollback of database state are separate concerns. Module migrations must be backward-compatible within one release window or explicitly marked as non-rollbackable.

## 17. Background Jobs

Business jobs belong to modules.

Core is not a scheduler or job runner in v1.

Modules choose and operate their own job mechanism.

Adapters may expose job metadata or status in the future. Core may later become a visibility/control panel, but not an executor of module business work.

## 18. External Integrations

External integrations are module-owned in v1.

Core does not store OAuth tokens for Google, Telegram, Discord, GitHub, or similar providers in v1.

Modules document their required external secrets and scopes.

A shared Core integration vault may be introduced later as a separate subsystem.

## 19. Module-To-Module Communication

Direct database access between modules is forbidden.

Undocumented internal calls between modules are forbidden.

In v1, runtime module-to-module communication is not required.

Future synchronous service-to-service calls must go through declared platform boundaries:

```text
Module A -> internal NGINX -> Core policy check -> Module B API
```

Future background service calls require declared dependencies and service credentials. User identity headers must not be reused for service calls.

Future asynchronous communication must use versioned events through an event bus. Core may manage declarations and policy, but must not become the domain event broker.

## 20. Events

Ayaya v1 is event-ready but broker-free.

Manifests may reserve event declaration sections, but modules must not rely on runtime event delivery in v1.

Future event contracts must define:

- event name;
- publisher;
- schema;
- version;
- delivery expectations;
- idempotency requirements;
- privacy constraints.

Kafka is not selected for v1.

## 21. Frontend Composition

Version 1 uses full-page module UI.

Core provides login, platform navigation, and admin UI.

Modules provide their own frontend.

Core does not embed modules through iframe or microfrontend composition in v1.

Modules should follow minimal UI guidelines:

- show module name clearly;
- provide a way back to the platform;
- handle forbidden and degraded states;
- be usable on desktop and mobile;
- avoid implementing a separate global authentication system.

## 22. Failure UX

Core owns platform-level unavailable and forbidden pages:

- unauthenticated;
- platform forbidden;
- disabled;
- maintenance;
- incompatible.

NGINX owns technical fallback for upstream failures, route mistakes, and 502-like errors.

Modules own domain-level errors:

- validation failures;
- local authorization failures;
- module-specific unavailable states.

Users should not see raw NGINX errors as normal product behavior.

## 23. Contract Testing

Documentation is not enough. Module compatibility must be mechanically testable.

Every module must pass contract tests before registration or update.

Contract tests must verify:

- `module.yml` schema;
- Adapter manifest schema;
- critical field equality between `module.yml` and runtime manifest;
- shared secret enforcement;
- health endpoint schemas;
- status endpoint schema;
- declared capabilities match implemented endpoints;
- route metadata exists;
- access defaults are valid;
- `module_key` is valid and stable;
- no forbidden platform assumptions are present.

