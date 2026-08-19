# Task 4 report — Planning module

## Delivered

- Added owner-scoped `PATCH /m/planning/plan_items/:id/position` with JSON success, validation, and not-found responses.
- Added transactional priority-lane normalization through `PlanItemPositioner`; ordinary HTML move forms use the same behavior without JavaScript.
- Added the internal Rails status endpoint with constant-time bearer authentication and database health reporting; adapter readiness now requires a healthy app database.
- Added executable Selenium/Capybara coverage for JavaScript moves, keyboard move controls, and narrow layout, plus no-JavaScript controller coverage.
- Addressed Task 3 review findings: associated priority-select label, improved rail text contrast, explicit end-of-lane drag constraint, and optimistic success/rollback live-region messages.
- Documented environment, migration, health, and position-route behavior.

## Verification

- Focused Rails controller suite: 9 runs, 44 assertions, 0 failures/errors.
- Full planning Rails suite: 26 runs, 113 assertions, 0 failures/errors.
- Full planning adapter suite: 13 passed.
- Brakeman 8.0.6: 0 security warnings.
- Final browser accessibility suite: 6 runs, 24 assertions, 0 failures/errors.
- A follow-up `graphify update .` completed successfully after the earlier watcher failure.

## Notes

- Current test status: no test blocker. Browser coverage executed successfully in the Docker image after installing Chromium and passing its container flags.
- The host Ruby 2.6 environment lacks the module's `pg` bundle, so Rails verification was run in the module's Ruby 3.4 Docker image.
- The earlier Graphify watcher failure was superseded by the successful follow-up refresh recorded in Verification; no Graphify mutation was included in this final-fix scope.
- RuboCop reports 507 existing offenses across the 39-file module baseline and is not currently a clean gate. No unrelated cleanup was included.

## Follow-up review fixes

- The JSON position endpoint now requires both `priority` and `position`; empty and partial payloads return `422`.
- Normal item updates validate editable attributes before entering the reorder transaction, preventing a failed title or notes update from persisting a lane move.
- Lane, inline-add, and inspector priority selects now have unique IDs and explicit associated labels. The inspector updates its label association as selection changes.
- Selected rail links use the darker `#6f4520` text color for normal-text contrast on the rail surface.
- Browser coverage now executes native `DataTransfer` drag-over/drop events to assert the insertion cue and persisted move, and stubs a failed request to assert rollback/live-region feedback. No browser-driver limitation was encountered.

### Follow-up verification

- Focused Rails controller/system/browser suite: 20 runs, 104 assertions, 0 failures/errors.
- Full planning Rails suite: 28 runs, 119 assertions, 0 failures/errors.
- Full planning adapter suite: 13 passed.
- Brakeman 8.0.6: 0 security warnings.

## Final-fix round

- Production Compose now sets `RAILS_ENV=production` and production-safe Puma, logging, static-file, thread, worker, and secret-key settings. The image runs Puma directly.
- The application entrypoint is boot-only; deployment documentation now requires the explicit `bin/rails db:migrate` step before startup.
- Item creation ignores client-supplied positions and appends within the current owner's selected plan and priority lane. Successful JavaScript moves now place the DOM node at the normalized position returned by the server.
- Adapter status parsing now accepts only contract runtime states, requires meaningful `app` and `database` component states, and converts malformed upstream payloads to the safe unreachable response.
- Planning deployment documentation now defines the NGINX route/header-stripping boundary and confirms that only Core-derived identity headers are trusted.

### Final-fix verification

- Red: the new creation-position and browser normalized-position tests failed against the prior behavior.
- Focused Rails controller/browser suite: 19 runs, 80 assertions, 0 failures/errors.
- Full planning Rails suite: 29 runs, 123 assertions, 0 failures/errors.
- Full planning adapter suite: 16 passed.
- `docker compose --project-name ayaya -f modules/planning/compose.yml config` completed successfully with the documented required environment values.
- Brakeman 8.0.6: 0 security warnings.

## Task 4 final fixes

### Delivered

- Successful JavaScript moves now reindex all lane item datasets and hidden move/lane form fields, refresh lane-select values, and reset up/down disabled states. A browser regression performs two keyboard moves without refreshing and checks the persisted order, disabled controls, and hidden positions.
- Adapter status now changes a contradictory `healthy` runtime to `unhealthy` when a known app or database component is non-healthy, and to `unreachable` when either required component is `unknown`. Existing malformed or missing component handling remains an unreachable fallback.
- Deployment documentation now contains an authenticated adapter readiness command, code/database rollback guidance, and PostgreSQL persistence, backup, restore-verification, and retention notes.

### Verification

- Red adapter regression: 2 intended failures before the coercion change (`healthy` had been emitted for unknown and contradictory components).
- Focused browser suite: 8 runs, 35 assertions, 0 failures/errors.
- Full Planning Rails suite: 29 runs, 123 assertions, 0 failures/errors.
- Full Planning adapter suite: 18 passed.
- JavaScript syntax and scoped whitespace checks passed.
- Planning Compose interpolation passed with inert placeholder credentials. The local `.env` lacks the required Planning secrets, so it cannot validate the bundle without placeholders.

### Notes

- Rails tests ran in the module Ruby 3.4/Chromium image with an isolated, auto-removed PostgreSQL container because the host Ruby lacks the `pg` bundle.
- No Core, unrelated files, agents, or Graphify output were changed in this final-fix scope.

## Review fixes — stored ordering and standalone topology

### Delivered

- `PlanItemPositioner` now loads a plan's items in stored `position`, then `id` order before grouping lanes. The controller regression creates three items whose persisted order differs from creation order, performs two moves, and verifies the untouched items retain their stored order.
- The standalone Planning Compose bundle attaches `planning_app` and `planning_adapter` to the root platform's external `ayaya_default` network. The README documents the exact network, service DNS reachability, Core registration endpoint, and static NGINX routing sequence.
- The established NGINX example now defines the `planning_app` upstream and authenticated `/m/planning` route. It uses the same Core `auth_request` and trusted-header allowlist as the existing module routes. The root NGINX/Compose contract test covers the new route; Core runtime code was not changed.

### RED / GREEN

- RED: the three-item position regression failed against the previous `order(:id)` implementation. After the first move it returned `[first, second, third]` instead of the stored-position result `[third, second, first]`.
- GREEN: loading with `order(:position, :id)` makes both moves preserve the expected ordering.

### Verification

- Focused Planning controller suite: 13 runs, 58 assertions, 0 failures/errors.
- Full Planning Rails suite: 30 runs, 127 assertions, 0 failures/errors.
- Full Planning adapter suite: 18 passed.
- Focused root NGINX/Compose contract suite: 9 runs, 114 assertions, 0 failures/errors.
- `docker compose --env-file .env --project-name ayaya-planning -f modules/planning/compose.yml config` passed with inert placeholder Planning secrets.
- `docker run --rm -v "$PWD/deploy/nginx/ayaya.example.conf:/etc/nginx/nginx.conf:ro" nginx:1.27-alpine nginx -t` passed.
- `git diff --check` passed.

### Concern

- The host Ruby 2.6 installation does not contain the Rails 8 bundle, so the root contract test ran in the existing Core container image against the isolated PostgreSQL container. The standalone bundle requires the root `ayaya` Compose project to have created the external `ayaya_default` network before deployment.
