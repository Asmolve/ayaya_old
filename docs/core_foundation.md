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

Module App ports must remain internal and must not be publicly exposed.
