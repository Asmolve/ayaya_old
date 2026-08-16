# Admin-Driven Local Module Registration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let an Ayaya administrator register Pic Obtainer from ActiveAdmin while centralizing local-module configuration for a future unified registration screen.

**Architecture:** Add a small `Modules::LocalRegistration` registry/service that resolves known local module metadata and server-side environment credentials. ActiveAdmin will use that boundary for a Pic Obtainer dashboard action and retain the existing `RegisterAdapter` service as the protocol implementation. No plaintext adapter secret enters a form, URL, database, or log.

**Tech Stack:** Rails 8.1, ActiveAdmin, Devise, Minitest, Docker Compose, PostgreSQL-backed `RegisteredModule` records.

## Global Constraints

- The existing Rails runner command remains available as a diagnostic fallback, but is no longer the primary documented registration path.
- The first local registration entry is `pic_obtainer` with display name `Pic Obtainer`.
- Adapter URL and secret are read only from Core server-side environment variables.
- The adapter secret is never rendered, redirected, logged by the new UI code, or persisted as plaintext.
- Registration is available only to Core administrators through ActiveAdmin.
- Repeated registration must not create a duplicate module record.
- Existing manifest refresh, status refresh, and enable actions must remain usable.
- The full Ayaya Rails test suite must remain green.

---

## File Map

- Create `app/services/modules/local_registration.rb`: immutable local-module configuration and registration entry point.
- Create `test/services/modules/local_registration_test.rb`: registry lookup, environment validation, successful registration, duplicate handling, and safe failures.
- Modify `app/admin/dashboard.rb`: expose the Pic Obtainer registration action and render it only when unregistered.
- Modify `test/integration/admin_access_test.rb`: cover admin-only dashboard action, POST workflow, safe failures, and hidden registered state.
- Modify `compose.yml`: pass `PIC_OBTAINER_ADAPTER_URL` into Core and use it for local registration.
- Modify `.env.example`: document the configurable Pic Obtainer adapter URL.
- Modify `modules/pic_obtainer/docs/REGISTER.md`: make ActiveAdmin the primary procedure and retain the Rails runner command as fallback diagnostics.

## Task 1: Add the local registration boundary

**Files:**
- Create: `app/services/modules/local_registration.rb`
- Create: `test/services/modules/local_registration_test.rb`
- Reference: `app/services/modules/register_adapter.rb`
- Reference: `app/services/modules/register_reference_notes.rb`

**Interfaces:**
- Produces `Modules::LocalRegistration.configuration("pic_obtainer")`, returning an immutable configuration with `module_key`, `display_name`, `adapter_url_env`, and `adapter_secret_env`.
- Produces `Modules::LocalRegistration.call("pic_obtainer")`, returning the existing `Modules::RegisterAdapter::Result` shape.
- Reads `ENV["PIC_OBTAINER_ADAPTER_URL"]` and `ENV["PIC_OBTAINER_AYAYA_ADAPTER_SECRET"]` only inside the service.

- [ ] **Step 1: Write failing service tests**

  Add tests that stub `ENV` and use the existing fake adapter client pattern. Cover:

  ```ruby
  test "resolves Pic Obtainer local registration configuration" do
    config = Modules::LocalRegistration.configuration("pic_obtainer")

    assert_equal "pic_obtainer", config.module_key
    assert_equal "Pic Obtainer", config.display_name
    assert_equal "PIC_OBTAINER_ADAPTER_URL", config.adapter_url_env
    assert_equal "PIC_OBTAINER_AYAYA_ADAPTER_SECRET", config.adapter_secret_env
  end

  test "registers Pic Obtainer with server-side credentials" do
    ENV["PIC_OBTAINER_ADAPTER_URL"] = "http://pic_obtainer_api:8000"
    ENV["PIC_OBTAINER_AYAYA_ADAPTER_SECRET"] = "secret"

    result = Modules::LocalRegistration.call("pic_obtainer", client: FakeClient.new(valid_manifest))

    assert result.success?
    assert_equal "pic_obtainer", result.registered_module.module_key
    assert_not_equal "secret", result.registered_module.adapter_secret_digest
  end

  test "returns a safe error when credentials are missing" do
    ENV.delete("PIC_OBTAINER_ADAPTER_URL")
    ENV.delete("PIC_OBTAINER_AYAYA_ADAPTER_SECRET")

    result = Modules::LocalRegistration.call("pic_obtainer")

    assert_not result.success?
    assert_includes result.errors.join("; "), "adapter URL"
    assert_not_includes result.errors.join("; "), "secret"
  end

  test "does not create a duplicate for an already registered module" do
    existing = create_registered_module(module_key: "pic_obtainer")

    result = Modules::LocalRegistration.call("pic_obtainer")

    assert result.success?
    assert_equal existing.id, result.registered_module.id
    assert_equal 1, RegisteredModule.where(module_key: "pic_obtainer").count
  end
  ```

- [ ] **Step 2: Run the focused test and verify it fails**

  Run:

  ```bash
  bundle exec rails test test/services/modules/local_registration_test.rb
  ```

  Expected: failure because `Modules::LocalRegistration` does not yet exist.

- [ ] **Step 3: Implement the minimal registry/service**

  Define a `Configuration = Data.define(:module_key, :display_name, :adapter_url_env, :adapter_secret_env)` value object and a frozen configuration map containing `pic_obtainer`. `configuration(key)` must return the entry or a failed result/error for an unknown key. `call(key, client: nil)` must:

  1. return the existing `RegisteredModule` with `success?: true` when the module key is already present;
  2. return a non-sensitive failure when either environment value is blank;
  3. call `Modules::RegisterAdapter.call(adapter_url:, adapter_secret:, client:)` otherwise;
  4. convert `KeyError`, connection failures, and adapter errors into the existing result shape without including the secret.

- [ ] **Step 4: Run the focused test and verify it passes**

  Run:

  ```bash
  bundle exec rails test test/services/modules/local_registration_test.rb
  ```

  Expected: all local registration service tests pass.

- [ ] **Step 5: Commit the service boundary**

  ```bash
  git add app/services/modules/local_registration.rb test/services/modules/local_registration_test.rb
  git commit -m "feat: add local module registration boundary"
  ```

## Task 2: Add the ActiveAdmin Pic Obtainer action

**Files:**
- Modify: `app/admin/dashboard.rb`
- Modify: `test/integration/admin_access_test.rb`
- Reference: `app/services/modules/local_registration.rb`

**Interfaces:**
- Adds `POST /admin/dashboard/register_pic_obtainer` through ActiveAdmin page action.
- Uses `Modules::LocalRegistration.call("pic_obtainer")` and redirects to `/admin/registered_modules/:id` on success.

- [ ] **Step 1: Write failing integration tests**

  Add tests for:

  ```ruby
  test "admin can register Pic Obtainer from the dashboard" do
    ENV["PIC_OBTAINER_ADAPTER_URL"] = "http://pic_obtainer_api:8000"
    ENV["PIC_OBTAINER_AYAYA_ADAPTER_SECRET"] = "secret"
    stub_pic_obtainer_registration_client
    admin = User.create!(email: "pic-admin@example.test", password: "password123", role: "admin")
    sign_in admin

    post admin_dashboard_register_pic_obtainer_path

    assert_redirected_to admin_registered_module_path(RegisteredModule.find_by!(module_key: "pic_obtainer"))
    assert_equal "registered", RegisteredModule.find_by!(module_key: "pic_obtainer").admin_state
  end

  test "dashboard shows Pic Obtainer registration only when absent" do
    admin = User.create!(email: "pic-dashboard-admin@example.test", password: "password123", role: "admin")
    sign_in admin

    get admin_root_path
    assert_includes response.body, "Register Pic Obtainer"

    create_registered_module(module_key: "pic_obtainer")
    get admin_root_path
    assert_not_includes response.body, "Register Pic Obtainer"
  end

  test "non-admin cannot register Pic Obtainer from the dashboard" do
    user = User.create!(email: "pic-user@example.test", password: "password123", role: "user")
    sign_in user

    post admin_dashboard_register_pic_obtainer_path

    assert_response :not_found
    assert_nil RegisteredModule.find_by(module_key: "pic_obtainer")
  end
  ```

  Also update the existing empty-dashboard expectation so it checks the new Pic Obtainer action alongside the Notes action where both are applicable.

- [ ] **Step 2: Run the focused integration tests and verify failure**

  ```bash
  bundle exec rails test test/integration/admin_access_test.rb
  ```

  Expected: failure because the page action and dashboard link do not exist.

- [ ] **Step 3: Implement the dashboard action**

  Add `page_action :register_pic_obtainer, method: :post`. Call the local registration service, redirect successful results to the registered module resource, and show `Pic Obtainer registration failed: ...` for failures. In the dashboard panel, render the link when `RegisteredModule.exists?(module_key: "pic_obtainer")` is false. Keep registration actions server-side and do not add a secret form field.

- [ ] **Step 4: Run the focused integration tests and verify success**

  ```bash
  bundle exec rails test test/integration/admin_access_test.rb
  ```

  Expected: all admin access tests pass, including registration, authorization, and dashboard visibility.

- [ ] **Step 5: Commit the ActiveAdmin workflow**

  ```bash
  git add app/admin/dashboard.rb test/integration/admin_access_test.rb
  git commit -m "feat: register Pic Obtainer from admin dashboard"
  ```

## Task 3: Wire the configurable adapter URL into Compose and documentation

**Files:**
- Modify: `compose.yml`
- Modify: `.env.example`
- Modify: `modules/pic_obtainer/docs/REGISTER.md`

**Interfaces:**
- Core receives `PIC_OBTAINER_ADAPTER_URL` from Compose.
- The documented local value is `http://pic_obtainer_api:8000`.

- [ ] **Step 1: Add the configuration contract**

  Add `PIC_OBTAINER_ADAPTER_URL` to `.env.example` with value `http://pic_obtainer_api:8000`, and pass it into the `core.environment` map in `compose.yml` as a required value. Keep the existing Pic Obtainer adapter secret wiring unchanged.

- [ ] **Step 2: Update the operator documentation**

  Rewrite the registration sequence so the primary path is:

  1. start the Compose services;
  2. open `/admin`;
  3. click `Register Pic Obtainer`;
  4. refresh manifest and status;
  5. set `admin_only` and enable the module.

  Retain the Rails runner command under a clearly labelled `Diagnostic fallback` section.

- [ ] **Step 3: Validate the Compose contract and documentation**

  Run:

  ```bash
  docker compose config
  rg -n "PIC_OBTAINER_ADAPTER_URL|Register Pic Obtainer|Diagnostic fallback" compose.yml .env.example modules/pic_obtainer/docs/REGISTER.md
  ```

  Expected: Compose resolves the new required Core variable when `.env` is configured, and documentation contains the admin-first workflow.

- [ ] **Step 4: Commit deployment and documentation changes**

  ```bash
  git add compose.yml .env.example modules/pic_obtainer/docs/REGISTER.md
  git commit -m "docs: make admin registration the Pic Obtainer workflow"
  ```

## Task 4: Full verification and reviewer handoff

**Files:**
- No source changes expected unless verification exposes a defect.

- [ ] **Step 1: Run the complete Ayaya test suite**

  ```bash
  bundle exec rails test
  ```

  Expected: zero failures and zero errors.

- [ ] **Step 2: Run the focused registration checks**

  ```bash
  bundle exec rails test test/services/modules/local_registration_test.rb test/integration/admin_access_test.rb
  ```

  Expected: registration service and ActiveAdmin workflow tests pass.

- [ ] **Step 3: Verify the working tree and graph metadata**

  ```bash
  git diff --check
  graphify update .
  git status --short
  ```

  Expected: no whitespace errors; graph metadata may be dirty by design, and unrelated existing changes must not be included in the feature commits.

- [ ] **Step 4: Request reviewer validation**

  Ask the configured `gpt-5.6-terra high` reviewer to inspect the implementation against the spec, with emphasis on secret handling, duplicate registration, authorization, and future registry extensibility. Address only actionable findings, rerun the focused and full suites, then commit fixes separately.
