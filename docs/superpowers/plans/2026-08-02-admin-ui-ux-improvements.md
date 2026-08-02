# Admin UI/UX Improvements Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn the existing ActiveAdmin area into a clearer internal operations console for module registration, status, and access control.

**Architecture:** Keep ActiveAdmin as the admin surface. Add small model/state helpers for module availability, then improve the dashboard and `RegisteredModule` resource pages. Wire admin actions to existing `Modules::*` service objects and keep adapter communication outside the ActiveAdmin DSL.

**Tech Stack:** Rails 8.1, ActiveAdmin 3.5, Devise, Propshaft, Minitest, Docker Compose local runtime.

## Global Constraints

- Do not replace ActiveAdmin.
- Do not build a separate React, Vue, Hotwire, or custom admin frontend.
- Do not expose adapter plaintext secrets or `adapter_secret_digest`.
- Do not allow direct admin editing of `runtime_status`, manifest snapshots, status snapshots, adapter URL, adapter protocol version, or refresh timestamps.
- Do not allow destructive module deletion in this phase.
- Use existing service objects: `Modules::RegisterAdapter`, `Modules::RefreshManifest`, and `Modules::RefreshStatus`.
- The reference Notes adapter URL is `http://notes_adapter:8080`.
- The reference Notes adapter secret is `development-notes-adapter-secret`.
- Keep UI copy operational and concise, not marketing-oriented.
- Keep tests primarily integration-level for admin workflow behavior.
- Preserve existing non-admin access restrictions for `/admin`.

---

## File Structure

- Modify `app/models/registered_module.rb`: add small state helper methods for admin UI decisions.
- Modify `app/admin/dashboard.rb`: replace the generated blank dashboard with module operations overview and empty state.
- Modify `app/admin/registered_modules.rb`: clean up list/show/form behavior and add member/collection actions.
- Modify `test/integration/admin_access_test.rb`: extend admin workflow coverage for dashboard, safe fields, and actions.
- Optionally modify `docs/core_foundation.md` and `modules/notes/docs/REGISTER.md`: document the new admin-driven local workflow after implementation.

---

### Task 1: RegisteredModule State Helpers

**Files:**
- Modify: `app/models/registered_module.rb`
- Modify: `test/models/registered_module_test.rb`

**Interfaces:**
- Produces: `RegisteredModule#user_available? -> Boolean`
- Produces: `RegisteredModule#ready_to_enable? -> Boolean`
- Produces: `RegisteredModule#availability_label -> String`
- Produces: `RegisteredModule#availability_blocker -> String`
- Produces: `RegisteredModule::USER_AVAILABLE_RUNTIME_STATUSES = %w[healthy degraded].freeze`

- [ ] **Step 1: Write failing model tests**

Add tests to `test/models/registered_module_test.rb`:

```ruby
test "ready to enable when registered with usable runtime status" do
  mod = build_module(admin_state: "registered", runtime_status: "healthy")

  assert mod.ready_to_enable?
  assert_equal "ready to enable", mod.availability_label
  assert_equal "Module is registered and healthy. Enable it to make it available.", mod.availability_blocker
end

test "available to users when enabled with usable runtime status" do
  mod = build_module(admin_state: "enabled", runtime_status: "degraded")

  assert mod.user_available?
  assert_equal "available", mod.availability_label
  assert_equal "Users can access this module.", mod.availability_blocker
end

test "explains disabled and unhealthy module states" do
  disabled = build_module(admin_state: "disabled", runtime_status: "healthy")
  unhealthy = build_module(admin_state: "enabled", runtime_status: "unreachable")

  assert_not disabled.user_available?
  assert_equal "disabled", disabled.availability_label
  assert_equal "Module is disabled by an admin.", disabled.availability_blocker

  assert_not unhealthy.user_available?
  assert_equal "needs attention", unhealthy.availability_label
  assert_equal "Module runtime is unreachable. Refresh status or fix the module service.", unhealthy.availability_blocker
end
```

- [ ] **Step 2: Run tests to verify RED**

Run:

```bash
bin/rails test test/models/registered_module_test.rb
```

Expected: fail because helper methods are missing.

- [ ] **Step 3: Implement minimal helpers**

In `app/models/registered_module.rb`, add:

```ruby
USER_AVAILABLE_RUNTIME_STATUSES = %w[healthy degraded].freeze

def user_available?
  admin_state == "enabled" && USER_AVAILABLE_RUNTIME_STATUSES.include?(runtime_status)
end

def ready_to_enable?
  admin_state == "registered" && USER_AVAILABLE_RUNTIME_STATUSES.include?(runtime_status)
end

def availability_label
  return "available" if user_available?
  return "ready to enable" if ready_to_enable?
  return "maintenance" if admin_state == "maintenance"
  return "disabled" if admin_state == "disabled"

  "needs attention"
end

def availability_blocker
  return "Users can access this module." if user_available?
  return "Module is registered and healthy. Enable it to make it available." if ready_to_enable?
  return maintenance_reason.presence || "Module is in maintenance mode." if admin_state == "maintenance"
  return "Module is disabled by an admin." if admin_state == "disabled"
  return "Module runtime is #{runtime_status}. Refresh status or fix the module service." unless USER_AVAILABLE_RUNTIME_STATUSES.include?(runtime_status)

  "Module is not enabled for users."
end
```

Update `enabled_for_users?` to delegate to `user_available?`.

- [ ] **Step 4: Run tests to verify GREEN**

Run:

```bash
bin/rails test test/models/registered_module_test.rb
```

Expected: pass.

- [ ] **Step 5: Commit**

```bash
git add app/models/registered_module.rb test/models/registered_module_test.rb
git commit -m "Add module availability helpers"
```

---

### Task 2: ActiveAdmin Dashboard Operations Overview

**Files:**
- Modify: `app/admin/dashboard.rb`
- Modify: `test/integration/admin_access_test.rb`

**Interfaces:**
- Consumes: `RegisteredModule#availability_label`
- Consumes: `RegisteredModule#availability_blocker`
- Consumes: `RegisteredModule#ready_to_enable?`
- Consumes: `RegisteredModule#user_available?`

- [ ] **Step 1: Write failing dashboard tests**

Add tests to `test/integration/admin_access_test.rb`:

```ruby
test "admin dashboard explains empty module registry" do
  admin = User.create!(email: "empty-dashboard-admin@example.test", password: "password123", role: "admin")
  sign_in admin

  get admin_root_path

  assert_response :success
  assert_includes response.body, "No modules registered"
  assert_includes response.body, "Register the local Notes adapter"
end

test "admin dashboard shows module operations summary" do
  admin = User.create!(email: "dashboard-admin@example.test", password: "password123", role: "admin")
  RegisteredModule.create!(
    module_key: "notes",
    name: "Notes",
    version: "0.1.0",
    adapter_url: "http://notes_adapter:8080",
    adapter_secret_digest: "digest",
    adapter_protocol_version: "1.0",
    admin_state: "registered",
    runtime_status: "healthy",
    access_policy_mode: "authenticated",
    manifest_snapshot: {},
    status_snapshot: {},
  )
  sign_in admin

  get admin_root_path

  assert_response :success
  assert_includes response.body, "Module Operations"
  assert_includes response.body, "Notes"
  assert_includes response.body, "ready to enable"
end
```

- [ ] **Step 2: Run tests to verify RED**

Run:

```bash
bin/rails test test/integration/admin_access_test.rb
```

Expected: fail because dashboard still renders the generated blank slate.

- [ ] **Step 3: Implement dashboard content**

Replace the generated dashboard content in `app/admin/dashboard.rb` with:

- a `Module Operations` panel;
- an empty state containing `No modules registered` and `Register the local Notes adapter`;
- summary counts for registered modules, enabled modules, usable modules, and modules needing attention;
- a table with module key, name, admin state, runtime status, access policy, and availability label;
- links to `admin_registered_modules_path` and each module show page.

Use ActiveAdmin DSL primitives: `panel`, `div`, `table_for`, `columns`, `column`, `link_to`, `status_tag`, and `para`.

- [ ] **Step 4: Run tests to verify GREEN**

Run:

```bash
bin/rails test test/integration/admin_access_test.rb
```

Expected: pass.

- [ ] **Step 5: Commit**

```bash
git add app/admin/dashboard.rb test/integration/admin_access_test.rb
git commit -m "Improve admin dashboard module overview"
```

---

### Task 3: Registered Modules Resource UX Cleanup

**Files:**
- Modify: `app/admin/registered_modules.rb`
- Modify: `test/integration/admin_access_test.rb`

**Interfaces:**
- Consumes: `RegisteredModule#availability_label`
- Consumes: `RegisteredModule#availability_blocker`
- Produces: ActiveAdmin resource with no `new`, `create`, or `destroy` actions.

- [ ] **Step 1: Write failing resource UX tests**

Add tests to `test/integration/admin_access_test.rb`:

```ruby
test "registered modules admin does not expose manual create or destroy actions" do
  ActiveAdmin.application.load!
  resource = ActiveAdmin.application.namespaces[:admin].resources[RegisteredModule]

  assert_not_includes resource.defined_actions, :new
  assert_not_includes resource.defined_actions, :create
  assert_not_includes resource.defined_actions, :destroy
  assert_empty resource.batch_actions
end

test "registered module form exposes only safe policy fields" do
  admin = User.create!(email: "safe-form-admin@example.test", password: "password123", role: "admin")
  mod = RegisteredModule.create!(
    module_key: "notes",
    name: "Notes",
    version: "0.1.0",
    adapter_url: "http://notes_adapter:8080",
    adapter_secret_digest: "digest",
    adapter_protocol_version: "1.0",
    admin_state: "registered",
    runtime_status: "healthy",
    access_policy_mode: "authenticated",
    manifest_snapshot: {},
    status_snapshot: {},
  )
  sign_in admin

  get edit_admin_registered_module_path(mod)

  assert_response :success
  assert_includes response.body, "admin_state"
  assert_includes response.body, "access_policy_mode"
  assert_includes response.body, "maintenance_reason"
  assert_not_includes response.body, "adapter_secret_digest"
  assert_not_includes response.body, "runtime_status"
  assert_not_includes response.body, "manifest_snapshot"
end
```

- [ ] **Step 2: Run tests to verify RED**

Run:

```bash
bin/rails test test/integration/admin_access_test.rb
```

Expected: fail because create/destroy and current fields are still exposed in default ActiveAdmin behavior.

- [ ] **Step 3: Clean up resource actions and page content**

In `app/admin/registered_modules.rb`:

- add `actions :all, except: %i[new create destroy]`;
- add `config.batch_actions = false`;
- remove `selectable_column`;
- replace `id_column` with `column :module_key`;
- add a human availability column using `availability_label`;
- keep `actions defaults: true`;
- add help text with `hint:` for `admin_state`, `access_policy_mode`, `maintenance_reason`, and `allowed_users`;
- keep `permit_params :admin_state, :access_policy_mode, :maintenance_reason, user_ids: []`;
- keep snapshots on show page inside secondary diagnostic panels.

- [ ] **Step 4: Run tests to verify GREEN**

Run:

```bash
bin/rails test test/integration/admin_access_test.rb
```

Expected: pass.

- [ ] **Step 5: Commit**

```bash
git add app/admin/registered_modules.rb test/integration/admin_access_test.rb
git commit -m "Clarify registered modules admin resource"
```

---

### Task 4: Module Operational Admin Actions

**Files:**
- Create: `app/services/modules/register_reference_notes.rb`
- Modify: `app/admin/dashboard.rb`
- Modify: `app/admin/registered_modules.rb`
- Modify: `test/integration/admin_access_test.rb`
- Modify: `docs/core_foundation.md`
- Modify: `modules/notes/docs/REGISTER.md`

**Interfaces:**
- Produces: `Modules::RegisterReferenceNotes.call -> Modules::RegisterAdapter::Result`
- Consumes: `Modules::RegisterAdapter.call(adapter_url:, adapter_secret:)`
- Consumes: `Modules::RefreshManifest.call(registered_module:, adapter_secret:)`
- Consumes: `Modules::RefreshStatus.call(registered_module:, adapter_secret:)`

- [ ] **Step 1: Write failing action tests**

Add tests to `test/integration/admin_access_test.rb`:

```ruby
test "admin can enable a healthy registered module" do
  admin = User.create!(email: "enable-admin@example.test", password: "password123", role: "admin")
  mod = RegisteredModule.create!(
    module_key: "notes",
    name: "Notes",
    version: "0.1.0",
    adapter_url: "http://notes_adapter:8080",
    adapter_secret_digest: "digest",
    adapter_protocol_version: "1.0",
    admin_state: "registered",
    runtime_status: "healthy",
    access_policy_mode: "authenticated",
    manifest_snapshot: {},
    status_snapshot: {},
  )
  sign_in admin

  post enable_admin_registered_module_path(mod)

  assert_redirected_to admin_registered_module_path(mod)
  assert_equal "enabled", mod.reload.admin_state
end

test "admin cannot enable an unhealthy registered module" do
  admin = User.create!(email: "blocked-enable-admin@example.test", password: "password123", role: "admin")
  mod = RegisteredModule.create!(
    module_key: "notes",
    name: "Notes",
    version: "0.1.0",
    adapter_url: "http://notes_adapter:8080",
    adapter_secret_digest: "digest",
    adapter_protocol_version: "1.0",
    admin_state: "registered",
    runtime_status: "unreachable",
    access_policy_mode: "authenticated",
    manifest_snapshot: {},
    status_snapshot: {},
  )
  sign_in admin

  post enable_admin_registered_module_path(mod)

  assert_redirected_to admin_registered_module_path(mod)
  assert_equal "registered", mod.reload.admin_state
end

test "admin can disable and enter maintenance mode" do
  admin = User.create!(email: "state-admin@example.test", password: "password123", role: "admin")
  mod = RegisteredModule.create!(
    module_key: "notes",
    name: "Notes",
    version: "0.1.0",
    adapter_url: "http://notes_adapter:8080",
    adapter_secret_digest: "digest",
    adapter_protocol_version: "1.0",
    admin_state: "enabled",
    runtime_status: "healthy",
    access_policy_mode: "authenticated",
    manifest_snapshot: {},
    status_snapshot: {},
  )
  sign_in admin

  post disable_admin_registered_module_path(mod)
  assert_equal "disabled", mod.reload.admin_state

  post maintenance_admin_registered_module_path(mod), params: { maintenance_reason: "Upgrade" }
  assert_equal "maintenance", mod.reload.admin_state
  assert_equal "Upgrade", mod.maintenance_reason
end
```

- [ ] **Step 2: Run tests to verify RED**

Run:

```bash
bin/rails test test/integration/admin_access_test.rb
```

Expected: fail because routes/actions do not exist.

- [ ] **Step 3: Add reference registration service**

Create `app/services/modules/register_reference_notes.rb`:

```ruby
module Modules
  class RegisterReferenceNotes
    ADAPTER_URL = "http://notes_adapter:8080"
    ADAPTER_SECRET = "development-notes-adapter-secret"

    def self.call
      existing = RegisteredModule.find_by(module_key: "notes")
      return RegisterAdapter::Result.new(success?: true, registered_module: existing, errors: []) if existing

      RegisterAdapter.call(adapter_url: ADAPTER_URL, adapter_secret: ADAPTER_SECRET)
    end
  end
end
```

- [ ] **Step 4: Add ActiveAdmin actions**

In `app/admin/registered_modules.rb`, add member actions:

- `enable`;
- `disable`;
- `maintenance`;
- `clear_maintenance`;
- `refresh_manifest`;
- `refresh_status`.

Use `redirect_to resource_path(resource), notice: ...` on success and `alert: ...` on failure.

Rules:

- `enable` updates only if `resource.ready_to_enable?` or `resource.runtime_status.in?(RegisteredModule::USER_AVAILABLE_RUNTIME_STATUSES)`;
- `disable` sets `admin_state: "disabled"`;
- `maintenance` sets `admin_state: "maintenance"` and `maintenance_reason` from params;
- `clear_maintenance` sets `admin_state: "registered"` and clears `maintenance_reason`;
- refresh actions use `development-notes-adapter-secret` only for the current reference runtime.

Add action items on show page for each action.

- [ ] **Step 5: Add dashboard registration action**

In `app/admin/dashboard.rb`, add a `page_action :register_reference_notes, method: :post` that calls `Modules::RegisterReferenceNotes.call`.

Add a button/link in the empty state:

```ruby
link_to "Register the local Notes adapter", admin_register_reference_notes_path, method: :post
```

- [ ] **Step 6: Update documentation**

Update `docs/core_foundation.md` and `modules/notes/docs/REGISTER.md` to state that the local reference Notes module can now be registered/refreshed/enabled from `/admin`.

Keep Rails runner commands as fallback diagnostics only.

- [ ] **Step 7: Run tests to verify GREEN**

Run:

```bash
bin/rails test test/integration/admin_access_test.rb
bin/rails test
bin/rubocop
```

Expected: all pass.

- [ ] **Step 8: Commit**

```bash
git add app/services/modules/register_reference_notes.rb app/admin/dashboard.rb app/admin/registered_modules.rb test/integration/admin_access_test.rb docs/core_foundation.md modules/notes/docs/REGISTER.md
git commit -m "Add module operations to ActiveAdmin"
```

---

## Final Verification

After all tasks:

```bash
bin/rails test
bin/rubocop
docker compose config --quiet
docker compose ps -a
```

If Docker services are running, verify:

```bash
docker compose exec -T core bin/rails runner 'puts RegisteredModule.order(:module_key).pluck(:module_key, :name, :admin_state, :runtime_status).map(&:inspect)'
```

Then run:

```bash
graphify update .
```

Commit tracked `graphify-out` updates separately if they changed.
