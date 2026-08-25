# Planning module implementation plan

Spec: `docs/superpowers/specs/2026-08-19-planning-module-design.md`

## Global constraints

- Preserve the independent module boundary; Core may own only Planning registry/access plumbing (registration, secret lookup, admin action, routing/network), never Planning domain logic.
- Use the existing notes bundle as the structural reference.
- Implement tests before production code and run each new test red before green.
- Keep the visual surface card-light, calm, responsive, and usable without drag-and-drop.
- User requested subagent-driven development with `gpt-5.6-terra` medium implementers and `gpt-5.6-terra` high reviewers.

## Task 1: Scaffold planning bundle and adapter contract

Files: create `modules/planning/module.yml`, `compose.yml`, adapter package, adapter tests, app Gemfile/config skeleton, module docs.

Implement the `planning` manifest with version `0.1.0`, paths `/m/planning` and `/m/planning/api`, authenticated access, and the standard v1 capabilities. Copy the notes adapter pattern but use `PLANNING_*` environment names and planning-specific app status URL. Add failing tests for secret enforcement, manifest equality, live health, ready failure, and status mapping; run pytest red, implement the adapter, run pytest green. Add minimal Rails boot/config files needed by the existing Docker and test conventions.

## Task 2: Domain model, identity, migrations, and HTML CRUD

Files: create Rails models/migrations/controllers/routes/tests/views.

Add `LocalUser`, `Plan`, and `PlanItem`; use enum values `now`, `next`, `later`; validate nonblank titles and owner scoping. Add migrations and controller tests for plan/item CRUD, invalid values, and cross-user 404 behavior. Implement the root workspace with plan navigation and the ability to create a plan and item. Run focused Rails tests red/green and then the full app test suite.

## Task 3: Priority Map UI and interaction behavior

Files: create/update app views, stylesheet, importmap JavaScript, system tests.

Build the single-workspace layout: plan rail, three priority lanes, inline add control, selected-item inspector, completion state, and accessible move-up/move-down/lane buttons. Add a small JavaScript controller for optimistic lane/order updates through the JSON endpoint, insertion cues, selection, and reduced-motion behavior. Cover system tests for creating/moving/reordering/completing items and a narrow viewport. Keep the fallback HTML controls functional when JavaScript is disabled.

## Task 4: Position endpoint and health integration

Files: create position controller/service/tests, internal status controller/tests, adapter status client integration tests, README/CONTRACT.

Add transactional position normalization and JSON responses, including invalid-payload handling. Add the internal status endpoint and ensure adapter readiness/status reflects the app database. Document build/start/migrate/health commands, env vars, and route behavior. Run focused tests red/green, then all module checks.

## Task 5: Whole-branch verification and cleanup

Review the complete module against the spec, run all applicable tests and static checks, inspect the final diff for accidental Core domain changes, run `graphify update .`, and fix any findings. Do not alter unrelated dirty worktree files.
