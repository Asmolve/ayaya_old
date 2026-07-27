# Ayaya Core Foundation Notes

## ActiveAdmin

Core administration is available under `/admin`.

Only `User` records with `role = admin` can access ActiveAdmin.

## Module Registry

The foundation slice supports module records, access policy editing, manifest snapshots, and runtime status snapshots.

Adapter registration can be wired into a custom ActiveAdmin action after the model and service tests pass.

## NGINX Static Routing

NGINX owns static module routing in v1.

Before proxying to a Module App, NGINX must call `/internal/auth/module_access` through `auth_request`.

NGINX must not trust incoming client-provided `X-Ayaya-*` headers. The example config sets platform headers from Core auth response values only.

The example config is a standalone NGINX configuration for direct `nginx -t -c` validation. The Module App route disables forwarding of client request headers and explicitly sets only the standard proxy headers and trusted platform headers.

Module App ports must remain internal and must not be publicly exposed.

## Foundation Verification

The foundation slice is complete when:

- Rails tests pass.
- Devise routes exist.
- ActiveAdmin routes exist.
- `/internal/auth/module_access` exists.
- Module registry models enforce valid states and access policy.
- Adapter manifest validation rejects invalid module keys and missing required capabilities.
- Adapter client sends `Authorization: Bearer <adapter_secret>`.
- Contract runner compares critical fields between `module.yml` and runtime manifest.
- Static NGINX example documents `auth_request` and trusted header injection.
