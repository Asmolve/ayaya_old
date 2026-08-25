# Admin-Driven Local Module Registration Design

## Status

Approved design for implementation planning.

## Goal

Allow an Ayaya administrator to register the local Pic Obtainer adapter from
ActiveAdmin without using a Rails console command, while keeping the design
ready for a future unified registration workflow for additional modules.

## Scope

This change covers the Core administration workflow for registering the
Pic Obtainer adapter. It does not change the adapter protocol, module runtime,
module database, or user-facing module GUI.

The existing Rails runner command remains available as a diagnostic fallback,
but it is no longer the primary documented registration path.

## Design

### Registration configuration boundary

Introduce a small `Modules::LocalRegistration` service or registry boundary
that resolves a known local module configuration by module key. Each
configuration provides:

- module key;
- display name;
- adapter URL environment variable name;
- adapter secret environment variable name.

The first configuration is:

```text
module_key: pic_obtainer
display_name: Pic Obtainer
adapter_url_env: PIC_OBTAINER_ADAPTER_URL
adapter_secret_env: PIC_OBTAINER_AYAYA_ADAPTER_SECRET
```

The default local Compose URL may remain the configured value in `.env`; the
admin UI must not hard-code deployment-specific hostnames beyond the existing
local module configuration.

### ActiveAdmin workflow

The ActiveAdmin dashboard exposes a `Register Pic Obtainer` action when the
module is not registered. The action:

1. resolves the Pic Obtainer local registration configuration;
2. reads the adapter URL and secret from Core's server-side environment;
3. validates that both values are present;
4. calls the existing `Modules::RegisterAdapter` service;
5. redirects to the registered module page on success;
6. displays a concise operational error on failure.

The secret is never rendered in a form, included in a redirect, logged by the
new UI code, or persisted as plaintext. Existing registration behavior stores
only the adapter secret digest.

If Pic Obtainer is already registered, the dashboard does not create a
duplicate. The UI directs the administrator to the existing module resource
where manifest and status refresh actions are available.

### Future unification

The ActiveAdmin action should depend on the local registration boundary rather
than calling Pic Obtainer-specific environment variables directly from the
view DSL. Adding another local module later should require adding a
configuration entry and an action/label mapping, not duplicating registration
or secret-handling logic.

A later iteration may replace per-module dashboard actions with a generic
`Register local module` screen backed by the same registry. That future work is
intentionally outside this change.

## Error handling

The UI reports actionable, non-sensitive errors for:

- missing adapter URL configuration;
- missing adapter secret configuration;
- unreachable adapter;
- invalid or incompatible manifest;
- adapter already registered.

Raw secrets and full exception backtraces must not appear in the response.

## Authorization

The registration action is available only through ActiveAdmin and therefore
only to Core users with the existing `admin` role. Non-admin users continue to
receive the existing forbidden behavior for `/admin`.

## Verification

Tests must cover:

- an admin can register Pic Obtainer through the ActiveAdmin action;
- successful registration persists the adapter record and secret digest;
- missing URL or secret produces a safe failure message;
- adapter errors produce a safe failure message;
- repeated registration does not create a duplicate;
- non-admin users cannot invoke the action;
- existing manifest/status refresh and enable actions remain usable after
  registration;
- the dashboard shows the registration action only while Pic Obtainer is not
  registered.

The full Ayaya Rails test suite must remain green.
