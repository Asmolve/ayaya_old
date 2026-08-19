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
