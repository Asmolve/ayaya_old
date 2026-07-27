# Final Fix Report

Date: 2026-07-27
Branch: `master`

## Findings fixed

- Module App NGINX routing keeps `proxy_pass_request_headers off` to prevent arbitrary client `X-Ayaya-*` headers from passing through. It explicitly restores the normal request-header allowlist and sets exactly the six trusted identity headers from `auth_request` values.
- Manifest refresh now rejects a valid manifest whose `identity.module_key` does not match the registered module. The module is marked `incompatible`; the previous manifest snapshot, Core access policy, and manifest-derived metadata remain unchanged.
- Status refresh now rejects non-object JSON responses. Transport failures become `unreachable`; unauthorized and invalid responses become `incompatible`; failures record an error snapshot and refresh timestamp.
- ActiveAdmin no longer permits `runtime_status` or manifest-derived `name`. Editable module fields are limited to `admin_state`, `access_policy_mode`, `maintenance_reason`, and allowlist users.
- User destruction is blocked at the model layer. Users remain persisted and must be deactivated.
- Added focused access-policy coverage for inactive users, `admin_only`, and manual allowlist grant/deny behavior.

## Verification

- Focused Rails tests: 20 tests, 57 assertions, 0 failures, 0 errors.
- Full Rails suite: 41 tests, 118 assertions, 0 failures, 0 errors.
- Ruby syntax checks passed for changed Ruby files.
- `git diff --check` passed.
- NGINX allowlist text checks passed, including `proxy_pass_request_headers off` and exactly six `X-Ayaya-*` proxy headers.

## Concern

The `nginx` binary is unavailable in this environment, so `nginx -t` syntax validation could not be run. The configuration was checked textually only.
