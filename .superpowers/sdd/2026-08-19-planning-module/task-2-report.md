# Task 2 report: planning module domain and HTML CRUD

## Delivered

- Added module-local `LocalUser`, `Plan`, and `PlanItem` models with owner associations, title validation, string priority enum (`now`, `next`, `later`), position, notes, and completion state.
- Added migrations for all three tables and indexes for local user identity and lane ordering.
- Added the `AyayaIdentity` concern for trusted planning-module headers and local-user refresh.
- Added owner-scoped workspace, plans, and plan-items HTML CRUD routes/controllers. Cross-user plan and item access returns 404.
- Added a calm, responsive workspace scaffold with a plan rail, priority lanes, and plan/item creation forms. Priority-map drag/reorder behavior remains intentionally deferred to Task 3/4.
- Added model and controller coverage for validation, identity, CRUD, owner scoping, invalid priority values, and cross-user 404 responses.

## TDD evidence

- Red: `bin/rails test test/models test/controllers` initially ran 17 tests with 4 failures and 13 errors because the models and routes did not yet exist.
- Green: the focused suite completed with 17 runs, 76 assertions, 0 failures, and 0 errors.
- Full app suite: `bin/rails test` completed with 17 runs, 76 assertions, 0 failures, and 0 errors.

## Scope notes

- No Core or adapter files were changed.
- The pre-existing uncommitted `modules/planning/app/Gemfile.lock` change was intentionally excluded from this task's commit.
- `graphify update .` was not run because it would modify `graphify-out/`, outside the user-authorized Task 2 scope.

---

## Independent review — 2026-08-19

Reviewed read-only against `f8ff084..112ed21`, Task 2 in
`docs/superpowers/plans/2026-08-19-planning-module.md`, and the planning-module design.
No agents were used.

### Spec compliance

- The three module-local records, owner relationships, nonblank titles, valid string
  priority enum, and database ownership are implemented.
- All implemented workspace, plan, and item lookups are scoped through
  `current_local_user`; cross-user plan/item updates and creates return 404.
- The identity concern requires the stable user ID and the planning module key, then
  maintains a local-user snapshot. This matches the module contract's required app
  headers.
- The migrations have required foreign keys, non-null/default priority, position, and
  completion fields, plus the intended plan/lane/position index.
- The root workspace supports creating plans and items. Transactional position
  normalization and the JSON position endpoint are correctly deferred to Task 4.
- Task 2 is not fully ready because the routes expose unusable conventional CRUD
  `index` and `new` endpoints.

### Strengths

- Ownership is enforced at the query boundary for plans and items, avoiding
  cross-user record disclosure or mutation.
- `priority` is a validated string enum with exactly `now`, `next`, and `later`.
- Completion has a database-level `NOT NULL DEFAULT false`; position has a
  database-level default and a model non-negative-integer validation.
- The focused tests cover identity denial, local-user snapshot creation, successful
  CRUD, invalid title/priority input, and representative cross-user 404s.

### Issues

#### Critical

None.

#### Important

1. `resources :plans` and `resources :plan_items` publish `index` and `new` routes,
   but neither controller implements `index` and neither has a `new` template. The
   `new` item action also builds through `current_local_user.plan_items`, which cannot
   supply the required plan association. Therefore normal authenticated requests to
   the advertised CRUD routes fail rather than provide HTML CRUD. Either remove the
   unused routes or implement them (including an owner-scoped plan selection for a
   new item).

   Evidence: `/Users/exsamption/projects/ayaya/modules/planning/app/config/routes.rb:4-5`,
   `/Users/exsamption/projects/ayaya/modules/planning/app/app/controllers/plans_controller.rb:10-12`,
   `/Users/exsamption/projects/ayaya/modules/planning/app/app/controllers/plan_items_controller.rb:10-12`, and
   `/Users/exsamption/projects/ayaya/modules/planning/app/app/controllers/plan_items_controller.rb:14-16`.

#### Minor

1. Validation coverage does not lock down malformed `position` or `completed`
   request values. The new tests prove invalid priority handling, but not the numeric
   position validator or boolean coercion path exposed by strong parameters. Add
   model and controller cases for negative/non-integer position and unexpected
   completion input.

   Evidence: `/Users/exsamption/projects/ayaya/modules/planning/app/app/models/plan_item.rb:4-7`,
   `/Users/exsamption/projects/ayaya/modules/planning/app/app/controllers/plan_items_controller.rb:54-55`, and
   `/Users/exsamption/projects/ayaya/modules/planning/app/test/models/plan_item_test.rb:21-27`.

2. The migration relies on Rails validations for the priority set and non-negative
   position. It has no database check constraints, so direct database writes can
   violate those invariants. This is defense-in-depth rather than an explicit Task 2
   requirement; consider PostgreSQL `CHECK` constraints if database-level integrity
   is required.

   Evidence: `/Users/exsamption/projects/ayaya/modules/planning/app/db/migrate/20260819000002_create_plan_items.rb:7-9`.

3. The identity test is titled as a refresh test but makes only one request, so it
   confirms initial snapshot creation rather than changed-header refresh behavior.

   Evidence: `/Users/exsamption/projects/ayaya/modules/planning/app/test/controllers/ayaya_identity_test.rb:16-24`.

### Ready assessment

**Not ready** until the exposed `index`/`new` routes are removed or made functional.
The owner scoping, identity enforcement, enum, completion default, and current
migrations otherwise meet Task 2's core requirements. `git diff --check
f8ff084..112ed21` passed. The locally available Ruby environments are missing the
module's bundled gems, so the reported Rails test results were not independently
rerun; no full suite was attempted.

---

## Review blocker fix — 2026-08-19

- Narrowed `plans` and `plan_items` to the usable Task 2 actions: `show`,
  `create`, `edit`, `update`, and `destroy`.
- Added numeric member-ID constraints so `/new` cannot be accidentally consumed
  by the `show` route.
- Removed the unreachable `new` actions from both controllers. There were no
  corresponding templates in the task implementation.
- Added focused controller coverage proving `show` and `edit` are usable and
  collection/new GET paths are absent for both resources.

### Test evidence

- Red: focused route-contract tests failed under broad resource routing because
  the unsupported collection routes resolved.
- Green: `bin/rails test test/controllers/plans_controller_test.rb
  test/controllers/plan_items_controller_test.rb` — 11 runs, 62 assertions,
  0 failures, 0 errors.
- Full: `bin/rails test` — 19 runs, 88 assertions, 0 failures, 0 errors.
