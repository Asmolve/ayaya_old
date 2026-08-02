# Admin UI/UX Improvements Design

## Purpose

The current Core admin is technically functional but not operationally clear. It exposes ActiveAdmin CRUD screens while the real administrator workflow is a control-plane process:

```text
module services running -> register adapter -> refresh manifest -> refresh status -> enable module -> users can access module
```

The goal of this phase is to turn the existing ActiveAdmin area into a usable internal operations console for a solo developer and AI agents, without building a separate frontend application.

This is not a visual redesign project. It is a workflow clarity and safety project.

## Current Problems

The current `/admin` experience has several practical failures:

- the dashboard does not explain what to do next;
- `/admin/registered_modules` can be empty even when module containers are running;
- the `New Registered Module` action suggests manual database creation, which is the wrong registration path;
- module registration, manifest refresh, status refresh, and enablement are hidden behind Rails runner commands;
- `admin_state`, `runtime_status`, and `access_policy_mode` require internal architecture knowledge;
- dangerous or technical fields are too visible for routine operation;
- the admin cannot distinguish "module service is down" from "module is not registered";
- there is no clear path from a blank admin screen to a usable module.

## Scope

This phase improves the existing ActiveAdmin implementation only.

In scope:

- a useful ActiveAdmin dashboard;
- clearer `RegisteredModule` index/show/form pages;
- explicit admin actions for module operations;
- safer field exposure and editing rules;
- empty states and help text;
- integration tests for the admin workflow;
- documentation updates for the new admin flow.

Out of scope:

- replacing ActiveAdmin;
- building a custom React/Vue/Hotwire admin app;
- dynamic module discovery across arbitrary networks;
- encrypted secret vaulting beyond the current adapter secret handling;
- background job scheduling for recurring status refresh;
- full audit log tables;
- role-based admin permissions beyond the existing `role = admin`;
- production-grade onboarding for non-technical operators.

## UX Principles

The admin UI must be quiet, dense, and operational. It should avoid marketing language, oversized hero sections, and decorative UI.

The primary operator questions are:

- What modules exist?
- Which modules are usable by users?
- Which modules need attention?
- What action should I take next?
- Did the last action succeed or fail?

Every admin screen should make one of these questions easier to answer.

## Target User

The target user is the project maintainer operating a local or early-stage Ayaya deployment.

Secondary users are AI agents delegated to perform narrowly scoped admin or development tasks. Therefore, the UI and code must expose clear state transitions and predictable action names.

## Dashboard Requirements

The ActiveAdmin dashboard must become the starting point for module operations.

It should show:

- total registered modules;
- modules enabled for users;
- modules with healthy or degraded runtime status;
- modules requiring attention;
- a compact table of module state.

The dashboard module table should include:

- module name;
- module key;
- admin state;
- runtime status;
- access policy;
- last manifest refresh time;
- last status refresh time;
- primary next action.

The dashboard must include an empty state when no modules are registered:

- explain that running containers are not automatically registered;
- show the expected registration path;
- provide a Notes-specific registration action for the local reference runtime if `notes_adapter` is configured.

The dashboard must not require the user to know Rails runner commands for the normal local Notes flow.

## Registered Modules Index Requirements

The `RegisteredModule` index should become an operational list, not a raw database table.

It should show:

- module key;
- display name;
- version;
- admin state;
- runtime status;
- access policy;
- last refreshed timestamps;
- concise next-step actions.

It should de-emphasize or remove:

- batch actions;
- the generic `New Registered Module` button;
- raw IDs as primary information.

Rows should make state obvious:

- `registered + healthy` means "ready to enable";
- `enabled + healthy` means "available";
- `enabled + unhealthy/unreachable` means "users may be blocked";
- `registered + unknown` means "refresh status";
- `maintenance` means "intentionally unavailable".

## Registered Module Show Page Requirements

The show page should be the main detail view for one module.

It should have sections:

- overview;
- availability;
- access policy;
- adapter connection;
- manifest snapshot;
- status snapshot;
- operational actions.

The overview section should show:

- module name;
- module key;
- version;
- description from manifest presentation metadata when available.

The availability section should show:

- admin state;
- runtime status;
- whether users can access it now;
- reason users cannot access it if blocked.

The adapter connection section should show:

- adapter URL;
- adapter protocol version;
- last manifest refresh timestamp;
- last status refresh timestamp.

The manifest and status snapshots should remain visible, but should be collapsed or visually secondary. They are diagnostic data, not primary UI.

## Form Requirements

The edit form should allow routine operational edits only:

- admin state;
- access policy mode;
- maintenance reason;
- allowed users for manual access.

The form should not allow editing:

- module key;
- name;
- version;
- adapter URL;
- adapter secret digest;
- adapter protocol version;
- runtime status;
- manifest snapshot;
- status snapshot;
- refresh timestamps.

Those fields are owned by adapter registration, manifest refresh, or status refresh.

Help text must explain:

- `admin_state`;
- `runtime_status`;
- `access_policy_mode`;
- `allowed_users`.

If `access_policy_mode` is not `manual`, the allowed users control should be visually de-emphasized or documented as inactive.

## Admin Actions

The admin UI should expose explicit actions instead of requiring Rails runner commands.

Required actions:

- Register Notes adapter;
- Refresh manifest;
- Refresh status;
- Enable module;
- Disable module;
- Set maintenance mode;
- Clear maintenance mode.

### Register Notes Adapter

For the reference local runtime, the admin may provide a fixed action that registers:

```text
adapter_url: http://notes_adapter:8080
adapter_secret: development-notes-adapter-secret
```

This action is for local development only. It should be clearly named as a local/reference action, not a general production discovery mechanism.

If the `notes` module is already registered, the action should not create a duplicate. It should direct the user to refresh manifest/status.

### Refresh Manifest

Refresh manifest must call `Modules::RefreshManifest`.

Success should update:

- name;
- version;
- adapter protocol version;
- manifest snapshot;
- `last_manifest_refreshed_at`.

Failure should show a clear error message and must not replace valid existing manifest data.

### Refresh Status

Refresh status must call `Modules::RefreshStatus`.

Success should update:

- runtime status;
- status snapshot;
- `last_status_refreshed_at`.

Failure should set the appropriate unavailable/unauthorized/incompatible state according to existing service behavior and show a clear admin message.

### Enable Module

Enable should set:

```text
admin_state = enabled
```

It should be available only when runtime status is `healthy` or `degraded`.

If runtime status is not usable, the UI should explain that the admin should refresh status or fix the module first.

### Disable Module

Disable should set:

```text
admin_state = disabled
```

It should preserve manifest and status snapshots.

### Maintenance Mode

Maintenance mode should set:

```text
admin_state = maintenance
maintenance_reason = <admin-provided reason>
```

The reason should be optional in the first implementation but the UI should encourage entering one.

Clear maintenance mode should return the module to `registered` or `enabled`. The first implementation should use `registered` unless the UI has enough context to safely restore the previous state.

## Safety Requirements

The admin UI must not expose adapter secrets.

The admin UI must not allow direct editing of `adapter_secret_digest`.

The admin UI must not allow direct editing of runtime status. Runtime status is adapter-reported state.

The admin UI must not allow destructive module deletion in the first implementation. Disabling is the safe operation.

The existing user deletion protection must remain.

Any action that changes module availability should produce a Rails log entry with:

- admin user id;
- module key;
- action name;
- result;
- error message if failed.

A dedicated audit table is deferred.

## Error Handling Requirements

Admin actions must report errors in plain operational language.

Examples:

- "Adapter is unreachable at http://notes_adapter:8080."
- "Adapter rejected the configured secret."
- "Manifest module key does not match registered module."
- "Module is unhealthy; refresh status after fixing the module service."

The UI must not show raw stack traces in normal admin action results.

The UI may include technical details in a collapsed diagnostic section.

## Visual And Interaction Direction

Visual thesis:

The admin should feel like a restrained operations console: compact, explicit, low ornament, with state and actions more prominent than raw database fields.

Content plan:

- Dashboard: state summary and next actions.
- Module index: scan and compare modules.
- Module show: understand one module and act.
- Module form: edit only safe policy fields.

Interaction thesis:

- State badges should make availability scannable.
- Actions should be close to the state they affect.
- Empty states should explain the next step instead of saying only that data is missing.

No heavy custom frontend is required. Use ActiveAdmin components and small helper methods before introducing custom CSS.

## Data Flow

Register reference module:

```text
Admin action -> Modules::RegisterAdapter -> AdapterProtocol::Client -> notes_adapter /ayaya/manifest -> RegisteredModule row
```

Refresh manifest:

```text
Admin action -> Modules::RefreshManifest -> notes_adapter /ayaya/manifest -> RegisteredModule manifest fields
```

Refresh status:

```text
Admin action -> Modules::RefreshStatus -> notes_adapter /ayaya/status -> RegisteredModule runtime fields
```

Enable access:

```text
Admin action -> registered_module.admin_state = enabled -> Home page and NGINX auth can expose module
```

User access remains governed by:

```text
RegisteredModule#accessible_by?(user)
```

## Implementation Boundaries

ActiveAdmin resource files may contain presentation and action wiring, but business transitions should live outside the view DSL when they become non-trivial.

Preferred boundaries:

- ActiveAdmin pages call service objects;
- existing `Modules::*` services own adapter communication;
- `RegisteredModule` owns simple state predicates;
- helper methods format statuses and next actions;
- tests verify behavior through HTTP/admin actions, not private helper internals.

If action logic grows beyond simple calls, introduce small service objects such as:

- `Modules::Enable`;
- `Modules::Disable`;
- `Modules::EnterMaintenance`;
- `Modules::RegisterReferenceNotes`.

## Testing Requirements

Add or update tests for:

- admin dashboard renders when no modules exist;
- admin dashboard renders registered modules;
- admin link crawler still passes;
- Notes reference registration action creates one `notes` module;
- repeated Notes registration is idempotent;
- refresh manifest action updates manifest fields;
- refresh status action updates runtime status;
- enable action succeeds only for `healthy` or `degraded` runtime status;
- unsafe fields cannot be edited through admin params;
- module deletion is unavailable through ActiveAdmin;
- non-admin users still cannot access `/admin`.

Keep tests mostly integration-level because this work is about admin workflow behavior.

## Acceptance Criteria

The phase is complete when:

- a new developer can open `/admin` and understand how to get Notes from unregistered to enabled;
- `/admin/registered_modules` no longer presents manual creation as the primary path;
- module status and access policy are understandable without reading code;
- Notes can be registered/refreshed/enabled from admin UI in local Docker runtime;
- raw technical snapshots remain available but secondary;
- dangerous fields are read-only or hidden from forms;
- all Rails tests pass;
- RuboCop passes;
- Docker Compose runtime can show `notes` as registered and healthy after admin action flow.

## Future Work

Deferred improvements:

- custom Core admin console outside ActiveAdmin;
- full audit log table;
- adapter registry for multiple module types;
- automatic registration on Compose startup;
- background status refresh;
- per-admin permission model;
- production secret management for adapter registration;
- visual design system for admin UI.
