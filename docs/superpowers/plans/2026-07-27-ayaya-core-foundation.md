# Ayaya Core Foundation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the first Ayaya Core foundation slice: Rails Core, user authentication, ActiveAdmin, module registry, Adapter Protocol validation/client, NGINX auth_request endpoint, and a first contract-test harness.

**Architecture:** Core is a Rails application that owns users, web sessions, module registry, module access policy, manifest snapshots, runtime status snapshots, and platform admin. Core communicates with modules only through Adapter Protocol endpoints and never proxies user traffic. User traffic is expected to go through NGINX static routes that call Core through `auth_request`.

**Tech Stack:** Ruby on Rails, PostgreSQL, Devise, ActiveAdmin, Rails system/unit tests, stdlib `Net::HTTP`, YAML/JSON schema-style Ruby validation.

## Global Constraints

- Core owns identity, sessions, module registry, module access policy, and platform administration.
- Core must not own module business logic, module domain data, module-local authorization rules, module background jobs, or module external integrations.
- Core communicates with modules only through their adapters.
- Core must never call a Module App directly.
- Adapter Protocol v1 is read-only from Core's perspective.
- User traffic flows through platform NGINX directly to Module Apps.
- NGINX routing is static in v1.
- Ayaya v1 uses web-first session authentication.
- Version 1 identity headers are `X-Ayaya-User-Id`, `X-Ayaya-User-Email`, `X-Ayaya-User-Display-Name`, `X-Ayaya-User-Role`, `X-Ayaya-Module-Key`, and `X-Ayaya-Request-Id`.
- Supported global roles in v1 are `user` and `admin`.
- `Guest` is not a persisted role.
- Users are not physically deleted in v1. Core supports deactivation.
- Runtime truth for Core is the Adapter API.
- Package truth for development and review is `module.yml`.
- Module state has two independent axes: `admin_state` and `runtime_status`.
- User access is allowed only when `admin_state = enabled` and runtime status is `healthy` or `degraded`.
- Supported v1 access modes are `authenticated`, `admin_only`, and `manual`.
- Core admins automatically pass the platform access gate for all enabled modules, subject to runtime status.
- Each module has a separate database inside the shared PostgreSQL instance in v1.
- Documentation is not enough. Module compatibility must be mechanically testable.
- Reviewer model preference: `gpt-5.6 Terra medium`.
- Subagent model preference: `gpt-5.6 Luna medium`.

---

## Scope Check

The approved architecture covers multiple independent subsystems: Core, NGINX, module contract tests, and the reference `notes` module. This plan implements the first independently testable foundation slice. A separate follow-up plan should implement the `notes` reference module against the contract produced here.

This plan intentionally does not implement:

- the `notes` module;
- dynamic NGINX generation;
- platform deployer;
- event bus;
- runtime service-to-service module calls;
- shared integration vault;
- module SDK/generator.

## File Structure

Create or modify these files:

- `Gemfile`: Rails dependencies, Devise, ActiveAdmin.
- `config/routes.rb`: Devise, ActiveAdmin, platform UI, internal auth_request endpoint.
- `config/database.yml`: PostgreSQL Core database configuration.
- `app/models/user.rb`: Core identity model with role and active state.
- `app/models/registered_module.rb`: Core module registry record.
- `app/models/module_user_access.rb`: Manual allowlist join model.
- `app/services/adapter_protocol/manifest_validator.rb`: Runtime manifest validation.
- `app/services/adapter_protocol/client.rb`: Core-to-Adapter HTTP client.
- `app/services/modules/register_adapter.rb`: Register module by adapter URL and secret.
- `app/services/modules/refresh_manifest.rb`: Refresh manifest snapshot.
- `app/services/modules/refresh_status.rb`: Refresh runtime status.
- `app/controllers/internal/module_access_controller.rb`: NGINX `auth_request` endpoint.
- `app/controllers/home_controller.rb`: Platform module list.
- `app/views/home/index.html.erb`: Simple platform navigation UI.
- `app/admin/users.rb`: ActiveAdmin user resource.
- `app/admin/registered_modules.rb`: ActiveAdmin module registry resource and admin actions.
- `app/lib/module_key.rb`: Shared module key parser/validator.
- `bin/ayaya-contract`: Contract test command skeleton for module adapters.
- `lib/ayaya_contract/manifest_loader.rb`: Contract test manifest loading.
- `lib/ayaya_contract/runner.rb`: Contract test runner.
- `test/models/user_test.rb`: User validation/role tests.
- `test/models/registered_module_test.rb`: Registry validation/policy tests.
- `test/services/adapter_protocol/manifest_validator_test.rb`: Manifest schema tests.
- `test/services/adapter_protocol/client_test.rb`: Adapter client tests using stubbed requests.
- `test/services/modules/register_adapter_test.rb`: Registration workflow tests.
- `test/controllers/internal/module_access_controller_test.rb`: NGINX auth_request behavior tests.
- `test/lib/ayaya_contract/runner_test.rb`: Contract runner tests.
- `deploy/nginx/ayaya.example.conf`: Static NGINX auth_request example.
- `docs/core_foundation.md`: Operational notes for the foundation slice.

---

### Task 1: Scaffold Rails Core And Test Baseline

**Files:**
- Create: Rails application files at repository root.
- Modify: `Gemfile`
- Modify: `config/database.yml`
- Modify: `config/routes.rb`
- Test: `test/application_system_test_case.rb`

**Interfaces:**
- Consumes: approved docs in `docs/project_overview.md`, `docs/architecture_constitution.md`, `docs/module_contract_v1.md`.
- Produces: a Rails Core application with PostgreSQL and a passing default test suite.

- [ ] **Step 1: Verify repository state**

Run:

```bash
git status --short
```

Expected: only known documentation files and local noise are present. Do not delete `.DS_Store` unless the user asks.

- [ ] **Step 2: Scaffold Rails in the repository root**

Run:

```bash
rails new . \
  --database=postgresql \
  --skip-action-mailbox \
  --skip-action-text \
  --skip-active-storage \
  --skip-jbuilder \
  --skip-kamal \
  --skip-thruster
```

Expected: Rails app files are created without deleting `docs/`.

If Rails refuses because the directory is not empty, rerun the same command with `--force` and inspect every overwritten file before committing.

- [ ] **Step 3: Add Core gems**

Modify `Gemfile` to include:

```ruby
gem "devise"
gem "activeadmin"
```

Keep Rails' default test framework. Do not add RSpec in this foundation plan.

- [ ] **Step 4: Install gems**

Run:

```bash
bundle install
```

Expected: `Gemfile.lock` is created or updated.

- [ ] **Step 5: Configure Core database names**

Modify `config/database.yml` so development and test databases are named:

```yaml
development:
  database: ayaya_core_development

test:
  database: ayaya_core_test
```

Preserve Rails' generated adapter, encoding, pool, username, password, host, and port style.

- [ ] **Step 6: Run the default test suite**

Run:

```bash
bin/rails test
```

Expected: PASS.

- [ ] **Step 7: Commit**

Run:

```bash
git add Gemfile Gemfile.lock config/database.yml config/routes.rb app config test bin db
git commit -m "chore: scaffold Rails core"
```

---

### Task 2: Add Unified User Authentication And ActiveAdmin

**Files:**
- Modify: `Gemfile`
- Create: `app/models/user.rb`
- Create: Devise migration for `users`
- Create: ActiveAdmin initializer and admin files
- Modify: `config/routes.rb`
- Test: `test/models/user_test.rb`

**Interfaces:**
- Consumes: Rails app from Task 1.
- Produces: `User` with `role`, `active`, `display_name`; Devise session auth; ActiveAdmin using `User` admins only.

- [ ] **Step 1: Generate Devise and ActiveAdmin**

Run:

```bash
bin/rails generate devise:install
bin/rails generate devise User
bin/rails generate active_admin:install --skip-users
```

Expected: Devise and ActiveAdmin files are generated. No `AdminUser` model is generated.

- [ ] **Step 2: Add user fields**

Generate a migration:

```bash
bin/rails generate migration AddPlatformFieldsToUsers display_name:string role:string active:boolean
```

Edit the generated migration to include defaults and null constraints:

```ruby
class AddPlatformFieldsToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :display_name, :string, null: false, default: ""
    add_column :users, :role, :string, null: false, default: "user"
    add_column :users, :active, :boolean, null: false, default: true

    add_index :users, :role
    add_index :users, :active
  end
end
```

If the generated migration superclass uses a Rails version other than `8.0`, keep the generated superclass version.

- [ ] **Step 3: Implement `User` model**

Replace the platform-specific part of `app/models/user.rb` with:

```ruby
class User < ApplicationRecord
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  ROLES = %w[user admin].freeze

  validates :role, inclusion: { in: ROLES }
  validates :display_name, length: { maximum: 120 }

  before_validation :default_display_name

  scope :active, -> { where(active: true) }
  scope :admins, -> { where(role: "admin") }

  def admin?
    role == "admin"
  end

  def active_for_authentication?
    super && active?
  end

  def inactive_message
    active? ? super : :inactive
  end

  private

  def default_display_name
    self.display_name = email.to_s.split("@").first if display_name.blank? && email.present?
  end
end
```

- [ ] **Step 4: Configure ActiveAdmin authentication**

In `config/initializers/active_admin.rb`, configure authentication methods:

```ruby
config.authentication_method = :authenticate_admin_user!
config.current_user_method = :current_user
config.logout_link_path = :destroy_user_session_path
```

In `app/controllers/application_controller.rb`, add:

```ruby
def authenticate_admin_user!
  authenticate_user!
  raise ActionController::RoutingError, "Not Found" unless current_user.admin?
end
```

- [ ] **Step 5: Register users in ActiveAdmin**

Create `app/admin/users.rb`:

```ruby
ActiveAdmin.register User do
  permit_params :email, :display_name, :role, :active, :password, :password_confirmation

  filter :email
  filter :display_name
  filter :role, as: :select, collection: User::ROLES
  filter :active

  index do
    selectable_column
    id_column
    column :email
    column :display_name
    column :role
    column :active
    column :created_at
    actions
  end

  form do |f|
    f.inputs do
      f.input :email
      f.input :display_name
      f.input :role, as: :select, collection: User::ROLES
      f.input :active
      f.input :password
      f.input :password_confirmation
    end
    f.actions
  end
end
```

- [ ] **Step 6: Add user tests**

Create `test/models/user_test.rb`:

```ruby
require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "defaults display name from email" do
    user = User.new(email: "alice@example.test", password: "password123", role: "user")

    assert user.valid?
    assert_equal "alice", user.display_name
  end

  test "rejects unknown role" do
    user = User.new(email: "alice@example.test", password: "password123", role: "owner")

    assert_not user.valid?
    assert_includes user.errors[:role], "is not included in the list"
  end

  test "inactive users cannot authenticate" do
    user = User.new(email: "alice@example.test", password: "password123", role: "user", active: false)

    assert_not user.active_for_authentication?
  end
end
```

- [ ] **Step 7: Run migrations and tests**

Run:

```bash
bin/rails db:create db:migrate
bin/rails test test/models/user_test.rb
```

Expected: PASS.

- [ ] **Step 8: Commit**

Run:

```bash
git add Gemfile Gemfile.lock app config db test
git commit -m "feat: add core user authentication"
```

---

### Task 3: Add Module Registry Models

**Files:**
- Create: `app/models/registered_module.rb`
- Create: `app/models/module_user_access.rb`
- Create: migrations for `registered_modules` and `module_user_accesses`
- Test: `test/models/registered_module_test.rb`

**Interfaces:**
- Consumes: `User` from Task 2.
- Produces: module registry persistence and access policy checks through `RegisteredModule#accessible_by?(user)`.

- [ ] **Step 1: Generate models**

Run:

```bash
bin/rails generate model RegisteredModule \
  module_key:string \
  name:string \
  version:string \
  adapter_url:string \
  adapter_secret_digest:string \
  adapter_protocol_version:string \
  admin_state:string \
  runtime_status:string \
  access_policy_mode:string \
  manifest_snapshot:jsonb \
  status_snapshot:jsonb \
  maintenance_reason:text \
  last_manifest_refreshed_at:datetime \
  last_status_refreshed_at:datetime

bin/rails generate model ModuleUserAccess registered_module:references user:references
```

- [ ] **Step 2: Tighten migrations**

Edit the `registered_modules` migration so important fields are constrained:

```ruby
t.string :module_key, null: false
t.string :name, null: false
t.string :version, null: false
t.string :adapter_url, null: false
t.string :adapter_secret_digest, null: false
t.string :adapter_protocol_version, null: false
t.string :admin_state, null: false, default: "registered"
t.string :runtime_status, null: false, default: "unknown"
t.string :access_policy_mode, null: false, default: "manual"
t.jsonb :manifest_snapshot, null: false, default: {}
t.jsonb :status_snapshot, null: false, default: {}
t.text :maintenance_reason
t.datetime :last_manifest_refreshed_at
t.datetime :last_status_refreshed_at

t.index :module_key, unique: true
t.index :admin_state
t.index :runtime_status
t.index :access_policy_mode
```

Edit the `module_user_accesses` migration:

```ruby
t.index [:registered_module_id, :user_id], unique: true, name: "index_module_access_on_module_and_user"
```

- [ ] **Step 3: Implement `RegisteredModule`**

Create `app/models/registered_module.rb`:

```ruby
class RegisteredModule < ApplicationRecord
  ADMIN_STATES = %w[registered enabled disabled maintenance].freeze
  RUNTIME_STATUSES = %w[unknown healthy degraded unhealthy unreachable incompatible].freeze
  ACCESS_POLICY_MODES = %w[authenticated admin_only manual].freeze
  MODULE_KEY_PATTERN = /\A[a-z][a-z0-9_]*[a-z0-9]\z/

  has_many :module_user_accesses, dependent: :destroy
  has_many :allowed_users, through: :module_user_accesses, source: :user

  validates :module_key, presence: true, uniqueness: true, format: { with: MODULE_KEY_PATTERN }
  validates :name, :version, :adapter_url, :adapter_secret_digest, :adapter_protocol_version, presence: true
  validates :admin_state, inclusion: { in: ADMIN_STATES }
  validates :runtime_status, inclusion: { in: RUNTIME_STATUSES }
  validates :access_policy_mode, inclusion: { in: ACCESS_POLICY_MODES }

  def enabled_for_users?
    admin_state == "enabled" && %w[healthy degraded].include?(runtime_status)
  end

  def accessible_by?(user)
    return false unless user&.active?
    return false unless enabled_for_users?
    return true if user.admin?

    case access_policy_mode
    when "authenticated"
      true
    when "admin_only"
      false
    when "manual"
      allowed_users.exists?(user.id)
    else
      false
    end
  end
end
```

- [ ] **Step 4: Implement `ModuleUserAccess`**

Create `app/models/module_user_access.rb`:

```ruby
class ModuleUserAccess < ApplicationRecord
  belongs_to :registered_module
  belongs_to :user

  validates :user_id, uniqueness: { scope: :registered_module_id }
end
```

- [ ] **Step 5: Add registry tests**

Create `test/models/registered_module_test.rb`:

```ruby
require "test_helper"

class RegisteredModuleTest < ActiveSupport::TestCase
  def build_module(attrs = {})
    RegisteredModule.new({
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
      status_snapshot: {}
    }.merge(attrs))
  end

  test "validates snake_case module key" do
    assert build_module(module_key: "shopping_list").valid?
    assert_not build_module(module_key: "shopping-list").valid?
    assert_not build_module(module_key: "ShoppingList").valid?
  end

  test "requires enabled admin state and healthy or degraded runtime status for user access" do
    user = User.create!(email: "user@example.test", password: "password123", role: "user")

    assert build_module(runtime_status: "healthy").accessible_by?(user)
    assert build_module(runtime_status: "degraded").accessible_by?(user)
    assert_not build_module(runtime_status: "unhealthy").accessible_by?(user)
    assert_not build_module(admin_state: "maintenance").accessible_by?(user)
  end

  test "admins access enabled modules regardless of manual allowlist" do
    admin = User.create!(email: "admin@example.test", password: "password123", role: "admin")
    mod = build_module(access_policy_mode: "manual")

    assert mod.accessible_by?(admin)
  end
end
```

- [ ] **Step 6: Migrate and test**

Run:

```bash
bin/rails db:migrate
bin/rails test test/models/registered_module_test.rb
```

Expected: PASS.

- [ ] **Step 7: Commit**

Run:

```bash
git add app/models db/migrate test/models
git commit -m "feat: add module registry models"
```

---

### Task 4: Implement Adapter Manifest Validation

**Files:**
- Create: `app/services/adapter_protocol/manifest_validator.rb`
- Test: `test/services/adapter_protocol/manifest_validator_test.rb`

**Interfaces:**
- Consumes: manifest contract from `docs/module_contract_v1.md`.
- Produces: `AdapterProtocol::ManifestValidator.call(manifest)` returning `Result`.

- [ ] **Step 1: Write failing validator tests**

Create `test/services/adapter_protocol/manifest_validator_test.rb`:

```ruby
require "test_helper"

class AdapterProtocol::ManifestValidatorTest < ActiveSupport::TestCase
  VALID_MANIFEST = {
    "identity" => {
      "module_key" => "notes",
      "name" => "Notes",
      "version" => "0.1.0"
    },
    "protocol" => {
      "adapter_protocol_version" => "1.0",
      "capabilities" => ["manifest.v1", "health.v1", "status.v1"]
    },
    "routes" => {
      "ui_base_path" => "/m/notes",
      "api_base_path" => "/m/notes/api"
    },
    "access" => {
      "default_policy" => "authenticated"
    }
  }.freeze

  test "accepts valid manifest" do
    result = AdapterProtocol::ManifestValidator.call(VALID_MANIFEST)

    assert result.valid?
    assert_empty result.errors
  end

  test "rejects invalid module key" do
    manifest = VALID_MANIFEST.deep_dup
    manifest["identity"]["module_key"] = "notes-app"

    result = AdapterProtocol::ManifestValidator.call(manifest)

    assert_not result.valid?
    assert_includes result.errors, "identity.module_key must be snake_case"
  end

  test "requires v1 capabilities" do
    manifest = VALID_MANIFEST.deep_dup
    manifest["protocol"]["capabilities"] = ["manifest.v1"]

    result = AdapterProtocol::ManifestValidator.call(manifest)

    assert_not result.valid?
    assert_includes result.errors, "protocol.capabilities must include health.v1"
    assert_includes result.errors, "protocol.capabilities must include status.v1"
  end

  test "requires routes under module namespace" do
    manifest = VALID_MANIFEST.deep_dup
    manifest["routes"]["ui_base_path"] = "/notes"

    result = AdapterProtocol::ManifestValidator.call(manifest)

    assert_not result.valid?
    assert_includes result.errors, "routes.ui_base_path must equal /m/notes"
  end
end
```

- [ ] **Step 2: Run tests to verify failure**

Run:

```bash
bin/rails test test/services/adapter_protocol/manifest_validator_test.rb
```

Expected: FAIL with `uninitialized constant AdapterProtocol`.

- [ ] **Step 3: Implement validator**

Create `app/services/adapter_protocol/manifest_validator.rb`:

```ruby
module AdapterProtocol
  class ManifestValidator
    Result = Struct.new(:valid?, :errors, keyword_init: true)

    REQUIRED_CAPABILITIES = %w[manifest.v1 health.v1 status.v1].freeze
    SUPPORTED_PROTOCOL_MAJOR = "1"
    MODULE_KEY_PATTERN = /\A[a-z][a-z0-9_]*[a-z0-9]\z/
    ACCESS_POLICIES = %w[authenticated admin_only manual].freeze

    def self.call(manifest)
      new(manifest).call
    end

    def initialize(manifest)
      @manifest = manifest || {}
      @errors = []
    end

    def call
      validate_identity
      validate_protocol
      validate_routes
      validate_access
      Result.new(valid?: errors.empty?, errors: errors)
    end

    private

    attr_reader :manifest, :errors

    def validate_identity
      identity = section("identity")
      add("identity.module_key is required") if identity["module_key"].blank?
      add("identity.name is required") if identity["name"].blank?
      add("identity.version is required") if identity["version"].blank?
      add("identity.module_key must be snake_case") if identity["module_key"].present? && !identity["module_key"].match?(MODULE_KEY_PATTERN)
    end

    def validate_protocol
      protocol = section("protocol")
      version = protocol["adapter_protocol_version"].to_s
      capabilities = Array(protocol["capabilities"])

      add("protocol.adapter_protocol_version is required") if version.blank?
      add("protocol.adapter_protocol_version major version is unsupported") if version.present? && version.split(".").first != SUPPORTED_PROTOCOL_MAJOR

      REQUIRED_CAPABILITIES.each do |capability|
        add("protocol.capabilities must include #{capability}") unless capabilities.include?(capability)
      end
    end

    def validate_routes
      identity = section("identity")
      routes = section("routes")
      module_key = identity["module_key"].to_s
      expected_ui = "/m/#{module_key}"
      expected_api = "/m/#{module_key}/api"

      add("routes.ui_base_path is required") if routes["ui_base_path"].blank?
      add("routes.api_base_path is required") if routes["api_base_path"].blank?
      add("routes.ui_base_path must equal #{expected_ui}") if module_key.present? && routes["ui_base_path"].present? && routes["ui_base_path"] != expected_ui
      add("routes.api_base_path must equal #{expected_api}") if module_key.present? && routes["api_base_path"].present? && routes["api_base_path"] != expected_api
    end

    def validate_access
      access = section("access")
      policy = access["default_policy"].to_s

      add("access.default_policy is required") if policy.blank?
      add("access.default_policy is unsupported") if policy.present? && !ACCESS_POLICIES.include?(policy)
    end

    def section(name)
      value = manifest[name]
      value.is_a?(Hash) ? value : {}
    end

    def add(message)
      errors << message
    end
  end
end
```

- [ ] **Step 4: Run validator tests**

Run:

```bash
bin/rails test test/services/adapter_protocol/manifest_validator_test.rb
```

Expected: PASS.

- [ ] **Step 5: Commit**

Run:

```bash
git add app/services/adapter_protocol/manifest_validator.rb test/services/adapter_protocol/manifest_validator_test.rb
git commit -m "feat: validate adapter manifests"
```

---

### Task 5: Implement Adapter HTTP Client

**Files:**
- Create: `app/services/adapter_protocol/client.rb`
- Test: `test/services/adapter_protocol/client_test.rb`

**Interfaces:**
- Consumes: adapter URL and secret from `RegisteredModule`.
- Produces: `AdapterProtocol::Client#manifest` and `AdapterProtocol::Client#status`.

- [ ] **Step 1: Write client tests**

Create `test/services/adapter_protocol/client_test.rb`:

```ruby
require "test_helper"
require "webmock/minitest"

class AdapterProtocol::ClientTest < ActiveSupport::TestCase
  test "fetches manifest with bearer secret" do
    stub_request(:get, "http://notes_adapter:8080/ayaya/manifest")
      .with(headers: { "Authorization" => "Bearer secret" })
      .to_return(status: 200, body: { identity: { module_key: "notes" } }.to_json, headers: { "Content-Type" => "application/json" })

    client = AdapterProtocol::Client.new(adapter_url: "http://notes_adapter:8080", adapter_secret: "secret")

    assert_equal "notes", client.manifest.dig("identity", "module_key")
  end

  test "raises unavailable on connection failure" do
    stub_request(:get, "http://notes_adapter:8080/ayaya/status").to_timeout
    client = AdapterProtocol::Client.new(adapter_url: "http://notes_adapter:8080", adapter_secret: "secret")

    assert_raises(AdapterProtocol::Client::Unavailable) { client.status }
  end

  test "raises unauthorized on 401" do
    stub_request(:get, "http://notes_adapter:8080/ayaya/manifest").to_return(status: 401)
    client = AdapterProtocol::Client.new(adapter_url: "http://notes_adapter:8080", adapter_secret: "secret")

    assert_raises(AdapterProtocol::Client::Unauthorized) { client.manifest }
  end
end
```

- [ ] **Step 2: Add WebMock for tests**

Add to `Gemfile`:

```ruby
group :test do
  gem "webmock"
end
```

Run:

```bash
bundle install
```

- [ ] **Step 3: Run tests to verify failure**

Run:

```bash
bin/rails test test/services/adapter_protocol/client_test.rb
```

Expected: FAIL with `uninitialized constant AdapterProtocol::Client`.

- [ ] **Step 4: Implement client**

Create `app/services/adapter_protocol/client.rb`:

```ruby
require "net/http"
require "json"

module AdapterProtocol
  class Client
    class Error < StandardError; end
    class Unauthorized < Error; end
    class Unavailable < Error; end
    class InvalidResponse < Error; end

    OPEN_TIMEOUT = 2
    READ_TIMEOUT = 5

    def initialize(adapter_url:, adapter_secret:)
      @adapter_uri = URI(adapter_url)
      @adapter_secret = adapter_secret
    end

    def manifest
      get_json("/ayaya/manifest")
    end

    def status
      get_json("/ayaya/status")
    end

    private

    attr_reader :adapter_uri, :adapter_secret

    def get_json(path)
      uri = adapter_uri + path
      request = Net::HTTP::Get.new(uri)
      request["Authorization"] = "Bearer #{adapter_secret}"
      request["Accept"] = "application/json"

      response = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https", open_timeout: OPEN_TIMEOUT, read_timeout: READ_TIMEOUT) do |http|
        http.request(request)
      end

      case response.code.to_i
      when 200
        JSON.parse(response.body)
      when 401, 403
        raise Unauthorized, "adapter rejected Core credentials"
      else
        raise Unavailable, "adapter returned HTTP #{response.code}"
      end
    rescue JSON::ParserError => e
      raise InvalidResponse, e.message
    rescue Timeout::Error, Errno::ECONNREFUSED, SocketError, Net::OpenTimeout, Net::ReadTimeout => e
      raise Unavailable, e.message
    end
  end
end
```

- [ ] **Step 5: Run client tests**

Run:

```bash
bin/rails test test/services/adapter_protocol/client_test.rb
```

Expected: PASS.

- [ ] **Step 6: Commit**

Run:

```bash
git add Gemfile Gemfile.lock app/services/adapter_protocol/client.rb test/services/adapter_protocol/client_test.rb
git commit -m "feat: add adapter protocol client"
```

---

### Task 6: Implement Module Registration And Refresh Services

**Files:**
- Create: `app/services/modules/register_adapter.rb`
- Create: `app/services/modules/refresh_manifest.rb`
- Create: `app/services/modules/refresh_status.rb`
- Test: `test/services/modules/register_adapter_test.rb`

**Interfaces:**
- Consumes: `AdapterProtocol::Client`, `AdapterProtocol::ManifestValidator`, `RegisteredModule`.
- Produces: service objects for ActiveAdmin actions.

- [ ] **Step 1: Write registration tests**

Create `test/services/modules/register_adapter_test.rb`:

```ruby
require "test_helper"

class Modules::RegisterAdapterTest < ActiveSupport::TestCase
  VALID_MANIFEST = {
    "identity" => { "module_key" => "notes", "name" => "Notes", "version" => "0.1.0" },
    "protocol" => { "adapter_protocol_version" => "1.0", "capabilities" => ["manifest.v1", "health.v1", "status.v1"] },
    "routes" => { "ui_base_path" => "/m/notes", "api_base_path" => "/m/notes/api" },
    "access" => { "default_policy" => "authenticated" }
  }.freeze

  FakeClient = Struct.new(:manifest_response, :status_response) do
    def manifest = manifest_response
    def status = status_response || { "runtime_status" => "healthy" }
  end

  test "registers module from adapter manifest" do
    result = Modules::RegisterAdapter.call(
      adapter_url: "http://notes_adapter:8080",
      adapter_secret: "secret",
      client: FakeClient.new(VALID_MANIFEST)
    )

    assert result.success?
    mod = result.registered_module
    assert_equal "notes", mod.module_key
    assert_equal "authenticated", mod.access_policy_mode
    assert_equal "registered", mod.admin_state
    assert_equal VALID_MANIFEST, mod.manifest_snapshot
  end

  test "rejects invalid manifest" do
    manifest = VALID_MANIFEST.deep_dup
    manifest["identity"]["module_key"] = "notes-app"

    result = Modules::RegisterAdapter.call(
      adapter_url: "http://notes_adapter:8080",
      adapter_secret: "secret",
      client: FakeClient.new(manifest)
    )

    assert_not result.success?
    assert_includes result.errors, "identity.module_key must be snake_case"
  end
end
```

- [ ] **Step 2: Run tests to verify failure**

Run:

```bash
bin/rails test test/services/modules/register_adapter_test.rb
```

Expected: FAIL with `uninitialized constant Modules`.

- [ ] **Step 3: Implement `Modules::RegisterAdapter`**

Create `app/services/modules/register_adapter.rb`:

```ruby
module Modules
  class RegisterAdapter
    Result = Struct.new(:success?, :registered_module, :errors, keyword_init: true)

    def self.call(adapter_url:, adapter_secret:, client: nil)
      new(adapter_url:, adapter_secret:, client:).call
    end

    def initialize(adapter_url:, adapter_secret:, client: nil)
      @adapter_url = adapter_url
      @adapter_secret = adapter_secret
      @client = client || AdapterProtocol::Client.new(adapter_url:, adapter_secret:)
    end

    def call
      manifest = client.manifest
      validation = AdapterProtocol::ManifestValidator.call(manifest)
      return Result.new(success?: false, errors: validation.errors) unless validation.valid?

      identity = manifest.fetch("identity")
      protocol = manifest.fetch("protocol")
      access = manifest.fetch("access")

      registered_module = RegisteredModule.new(
        module_key: identity.fetch("module_key"),
        name: identity.fetch("name"),
        version: identity.fetch("version"),
        adapter_url: adapter_url,
        adapter_secret_digest: digest_secret(adapter_secret),
        adapter_protocol_version: protocol.fetch("adapter_protocol_version"),
        admin_state: "registered",
        runtime_status: "unknown",
        access_policy_mode: access.fetch("default_policy"),
        manifest_snapshot: manifest,
        status_snapshot: {},
        last_manifest_refreshed_at: Time.current
      )

      if registered_module.save
        Result.new(success?: true, registered_module:, errors: [])
      else
        Result.new(success?: false, registered_module:, errors: registered_module.errors.full_messages)
      end
    rescue AdapterProtocol::Client::Error => e
      Result.new(success?: false, errors: [e.message])
    end

    private

    attr_reader :adapter_url, :adapter_secret, :client

    def digest_secret(secret)
      Digest::SHA256.hexdigest(secret)
    end
  end
end
```

- [ ] **Step 4: Implement refresh services**

Create `app/services/modules/refresh_manifest.rb`:

```ruby
module Modules
  class RefreshManifest
    Result = Struct.new(:success?, :registered_module, :errors, keyword_init: true)

    def self.call(registered_module:, adapter_secret:, client: nil)
      new(registered_module:, adapter_secret:, client:).call
    end

    def initialize(registered_module:, adapter_secret:, client: nil)
      @registered_module = registered_module
      @client = client || AdapterProtocol::Client.new(adapter_url: registered_module.adapter_url, adapter_secret:)
    end

    def call
      manifest = client.manifest
      validation = AdapterProtocol::ManifestValidator.call(manifest)
      return Result.new(success?: false, registered_module:, errors: validation.errors) unless validation.valid?

      registered_module.update!(
        name: manifest.dig("identity", "name"),
        version: manifest.dig("identity", "version"),
        adapter_protocol_version: manifest.dig("protocol", "adapter_protocol_version"),
        manifest_snapshot: manifest,
        last_manifest_refreshed_at: Time.current
      )

      Result.new(success?: true, registered_module:, errors: [])
    rescue AdapterProtocol::Client::Error, ActiveRecord::RecordInvalid => e
      Result.new(success?: false, registered_module:, errors: [e.message])
    end

    private

    attr_reader :registered_module, :client
  end
end
```

Create `app/services/modules/refresh_status.rb`:

```ruby
module Modules
  class RefreshStatus
    Result = Struct.new(:success?, :registered_module, :errors, keyword_init: true)

    VALID_STATUSES = %w[healthy degraded unhealthy unreachable incompatible].freeze

    def self.call(registered_module:, adapter_secret:, client: nil)
      new(registered_module:, adapter_secret:, client:).call
    end

    def initialize(registered_module:, adapter_secret:, client: nil)
      @registered_module = registered_module
      @client = client || AdapterProtocol::Client.new(adapter_url: registered_module.adapter_url, adapter_secret:)
    end

    def call
      status = client.status
      runtime_status = status.fetch("runtime_status", "unhealthy")
      runtime_status = "unhealthy" unless VALID_STATUSES.include?(runtime_status)

      registered_module.update!(
        runtime_status: runtime_status,
        status_snapshot: status,
        last_status_refreshed_at: Time.current
      )

      Result.new(success?: true, registered_module:, errors: [])
    rescue AdapterProtocol::Client::Unavailable => e
      registered_module.update!(runtime_status: "unreachable", status_snapshot: { "error" => e.message }, last_status_refreshed_at: Time.current)
      Result.new(success?: false, registered_module:, errors: [e.message])
    rescue AdapterProtocol::Client::Error, ActiveRecord::RecordInvalid => e
      Result.new(success?: false, registered_module:, errors: [e.message])
    end

    private

    attr_reader :registered_module, :client
  end
end
```

- [ ] **Step 5: Run service tests**

Run:

```bash
bin/rails test test/services/modules/register_adapter_test.rb
```

Expected: PASS.

- [ ] **Step 6: Commit**

Run:

```bash
git add app/services/modules test/services/modules
git commit -m "feat: add module registration services"
```

---

### Task 7: Add ActiveAdmin Module Registry UI

**Files:**
- Create: `app/admin/registered_modules.rb`
- Modify: `app/admin/users.rb`
- Test: manual admin smoke test documented in `docs/core_foundation.md`

**Interfaces:**
- Consumes: `RegisteredModule`, `ModuleUserAccess`, registration/refresh services.
- Produces: ActiveAdmin screens for managing module registry and access policy.

- [ ] **Step 1: Register module resource**

Create `app/admin/registered_modules.rb`:

```ruby
ActiveAdmin.register RegisteredModule do
  permit_params :name, :admin_state, :runtime_status, :access_policy_mode, :maintenance_reason, user_ids: []

  filter :module_key
  filter :name
  filter :admin_state, as: :select, collection: RegisteredModule::ADMIN_STATES
  filter :runtime_status, as: :select, collection: RegisteredModule::RUNTIME_STATUSES
  filter :access_policy_mode, as: :select, collection: RegisteredModule::ACCESS_POLICY_MODES

  index do
    selectable_column
    id_column
    column :module_key
    column :name
    column :version
    column :admin_state
    column :runtime_status
    column :access_policy_mode
    column :last_manifest_refreshed_at
    column :last_status_refreshed_at
    actions
  end

  show do
    attributes_table do
      row :module_key
      row :name
      row :version
      row :adapter_url
      row :adapter_protocol_version
      row :admin_state
      row :runtime_status
      row :access_policy_mode
      row :maintenance_reason
      row :last_manifest_refreshed_at
      row :last_status_refreshed_at
      row :manifest_snapshot do |record|
        pre JSON.pretty_generate(record.manifest_snapshot)
      end
      row :status_snapshot do |record|
        pre JSON.pretty_generate(record.status_snapshot)
      end
    end
  end

  form do |f|
    f.inputs do
      f.input :admin_state, as: :select, collection: RegisteredModule::ADMIN_STATES
      f.input :access_policy_mode, as: :select, collection: RegisteredModule::ACCESS_POLICY_MODES
      f.input :maintenance_reason
      f.input :allowed_users, as: :check_boxes, collection: User.active.order(:email)
    end
    f.actions
  end
end
```

- [ ] **Step 2: Add admin notes**

Create `docs/core_foundation.md`:

```markdown
# Ayaya Core Foundation Notes

## ActiveAdmin

Core administration is available under `/admin`.

Only `User` records with `role = admin` can access ActiveAdmin.

## Module Registry

The foundation slice supports module records, access policy editing, manifest snapshots, and runtime status snapshots.

Adapter registration can be wired into a custom ActiveAdmin action after the model and service tests pass.
```

- [ ] **Step 3: Run admin boot check**

Run:

```bash
bin/rails routes | grep admin
```

Expected: ActiveAdmin routes are listed.

- [ ] **Step 4: Run tests**

Run:

```bash
bin/rails test
```

Expected: PASS.

- [ ] **Step 5: Commit**

Run:

```bash
git add app/admin docs/core_foundation.md
git commit -m "feat: add module registry admin"
```

---

### Task 8: Implement NGINX `auth_request` Endpoint

**Files:**
- Create: `app/controllers/internal/module_access_controller.rb`
- Modify: `config/routes.rb`
- Test: `test/controllers/internal/module_access_controller_test.rb`

**Interfaces:**
- Consumes: Devise session auth and `RegisteredModule#accessible_by?`.
- Produces: `GET /internal/auth/module_access` returning 204 plus trusted headers, or 401/403/503.

- [ ] **Step 1: Add controller tests**

Create `test/controllers/internal/module_access_controller_test.rb`:

```ruby
require "test_helper"

class Internal::ModuleAccessControllerTest < ActionDispatch::IntegrationTest
  test "rejects unauthenticated request" do
    get "/internal/auth/module_access", headers: { "X-Original-URI" => "/m/notes" }

    assert_response :unauthorized
  end

  test "allows authenticated user for enabled healthy authenticated module" do
    user = User.create!(email: "user@example.test", password: "password123", role: "user", display_name: "User")
    sign_in user
    RegisteredModule.create!(
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
      status_snapshot: {}
    )

    get "/internal/auth/module_access", headers: { "X-Original-URI" => "/m/notes" }

    assert_response :no_content
    assert_equal user.id.to_s, response.headers["X-Ayaya-User-Id"]
    assert_equal "user@example.test", response.headers["X-Ayaya-User-Email"]
    assert_equal "User", response.headers["X-Ayaya-User-Display-Name"]
    assert_equal "user", response.headers["X-Ayaya-User-Role"]
    assert_equal "notes", response.headers["X-Ayaya-Module-Key"]
    assert response.headers["X-Ayaya-Request-Id"].present?
  end

  test "blocks unhealthy module" do
    user = User.create!(email: "user@example.test", password: "password123", role: "user")
    sign_in user
    RegisteredModule.create!(
      module_key: "notes",
      name: "Notes",
      version: "0.1.0",
      adapter_url: "http://notes_adapter:8080",
      adapter_secret_digest: "digest",
      adapter_protocol_version: "1.0",
      admin_state: "enabled",
      runtime_status: "unhealthy",
      access_policy_mode: "authenticated",
      manifest_snapshot: {},
      status_snapshot: {}
    )

    get "/internal/auth/module_access", headers: { "X-Original-URI" => "/m/notes" }

    assert_response :service_unavailable
  end
end
```

- [ ] **Step 2: Enable Devise test helpers**

In `test/test_helper.rb`, add:

```ruby
class ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers
end
```

- [ ] **Step 3: Add route**

Modify `config/routes.rb`:

```ruby
namespace :internal do
  get "auth/module_access", to: "module_access#show"
end
```

- [ ] **Step 4: Implement controller**

Create `app/controllers/internal/module_access_controller.rb`:

```ruby
module Internal
  class ModuleAccessController < ApplicationController
    before_action :authenticate_user!

    def show
      module_key = extract_module_key(request.headers["X-Original-URI"].to_s)
      return head :forbidden if module_key.blank?

      registered_module = RegisteredModule.find_by(module_key:)
      return head :not_found unless registered_module
      return head :service_unavailable unless %w[healthy degraded].include?(registered_module.runtime_status)
      return head :forbidden unless registered_module.accessible_by?(current_user)

      response.headers["X-Ayaya-User-Id"] = current_user.id.to_s
      response.headers["X-Ayaya-User-Email"] = current_user.email
      response.headers["X-Ayaya-User-Display-Name"] = current_user.display_name
      response.headers["X-Ayaya-User-Role"] = current_user.role
      response.headers["X-Ayaya-Module-Key"] = registered_module.module_key
      response.headers["X-Ayaya-Request-Id"] = request.request_id
      head :no_content
    end

    private

    def extract_module_key(original_uri)
      match = original_uri.match(%r{\A/m/([a-z][a-z0-9_]*[a-z0-9])(?:/|\z)})
      match && match[1]
    end
  end
end
```

- [ ] **Step 5: Run controller tests**

Run:

```bash
bin/rails test test/controllers/internal/module_access_controller_test.rb
```

Expected: PASS.

- [ ] **Step 6: Commit**

Run:

```bash
git add app/controllers/internal config/routes.rb test/test_helper.rb test/controllers/internal
git commit -m "feat: add module auth request endpoint"
```

---

### Task 9: Add Platform Module List UI

**Files:**
- Create: `app/controllers/home_controller.rb`
- Create: `app/views/home/index.html.erb`
- Modify: `config/routes.rb`
- Test: `test/controllers/home_controller_test.rb`

**Interfaces:**
- Consumes: `RegisteredModule#accessible_by?`.
- Produces: authenticated user's simple platform home page listing accessible modules.

- [ ] **Step 1: Add controller test**

Create `test/controllers/home_controller_test.rb`:

```ruby
require "test_helper"

class HomeControllerTest < ActionDispatch::IntegrationTest
  test "requires authentication" do
    get "/"

    assert_redirected_to new_user_session_path
  end

  test "lists accessible enabled modules" do
    user = User.create!(email: "user@example.test", password: "password123", role: "user")
    sign_in user
    RegisteredModule.create!(
      module_key: "notes",
      name: "Notes",
      version: "0.1.0",
      adapter_url: "http://notes_adapter:8080",
      adapter_secret_digest: "digest",
      adapter_protocol_version: "1.0",
      admin_state: "enabled",
      runtime_status: "healthy",
      access_policy_mode: "authenticated",
      manifest_snapshot: { "presentation" => { "description" => "Personal notes" } },
      status_snapshot: {}
    )

    get "/"

    assert_response :success
    assert_select "a[href='/m/notes']", text: "Notes"
    assert_includes response.body, "Personal notes"
  end
end
```

- [ ] **Step 2: Add route**

Modify `config/routes.rb`:

```ruby
root "home#index"
```

- [ ] **Step 3: Implement controller**

Create `app/controllers/home_controller.rb`:

```ruby
class HomeController < ApplicationController
  before_action :authenticate_user!

  def index
    @modules = RegisteredModule.order(:name).select { |mod| mod.accessible_by?(current_user) }
  end
end
```

- [ ] **Step 4: Implement view**

Create `app/views/home/index.html.erb`:

```erb
<main>
  <h1>Ayaya</h1>

  <nav>
    <% if current_user.admin? %>
      <%= link_to "Admin", admin_root_path %>
    <% end %>
    <%= button_to "Sign out", destroy_user_session_path, method: :delete %>
  </nav>

  <section>
    <h2>Modules</h2>

    <% if @modules.any? %>
      <ul>
        <% @modules.each do |registered_module| %>
          <% presentation = registered_module.manifest_snapshot.fetch("presentation", {}) %>
          <li>
            <%= link_to registered_module.name, "/m/#{registered_module.module_key}" %>
            <% if presentation["description"].present? %>
              <p><%= presentation["description"] %></p>
            <% end %>
          </li>
        <% end %>
      </ul>
    <% else %>
      <p>No modules are available.</p>
    <% end %>
  </section>
</main>
```

- [ ] **Step 5: Run tests**

Run:

```bash
bin/rails test test/controllers/home_controller_test.rb
```

Expected: PASS.

- [ ] **Step 6: Commit**

Run:

```bash
git add app/controllers/home_controller.rb app/views/home/index.html.erb config/routes.rb test/controllers/home_controller_test.rb
git commit -m "feat: add platform module list"
```

---

### Task 10: Add Contract Test Harness Skeleton

**Files:**
- Create: `bin/ayaya-contract`
- Create: `lib/ayaya_contract/manifest_loader.rb`
- Create: `lib/ayaya_contract/runner.rb`
- Test: `test/lib/ayaya_contract/runner_test.rb`

**Interfaces:**
- Consumes: `AdapterProtocol::ManifestValidator`.
- Produces: a local command shape for validating `module.yml` and an adapter manifest.

- [ ] **Step 1: Add runner tests**

Create `test/lib/ayaya_contract/runner_test.rb`:

```ruby
require "test_helper"

class AyayaContract::RunnerTest < ActiveSupport::TestCase
  VALID_MANIFEST = {
    "identity" => { "module_key" => "notes", "name" => "Notes", "version" => "0.1.0" },
    "protocol" => { "adapter_protocol_version" => "1.0", "capabilities" => ["manifest.v1", "health.v1", "status.v1"] },
    "routes" => { "ui_base_path" => "/m/notes", "api_base_path" => "/m/notes/api" },
    "access" => { "default_policy" => "authenticated" }
  }.freeze

  test "passes when package and runtime critical fields match" do
    runner = AyayaContract::Runner.new(package_manifest: VALID_MANIFEST, runtime_manifest: VALID_MANIFEST)

    assert runner.call.success?
  end

  test "fails when runtime module key differs" do
    runtime = VALID_MANIFEST.deep_dup
    runtime["identity"]["module_key"] = "other"
    runner = AyayaContract::Runner.new(package_manifest: VALID_MANIFEST, runtime_manifest: runtime)

    result = runner.call

    assert_not result.success?
    assert_includes result.errors, "critical field mismatch: identity.module_key"
  end
end
```

- [ ] **Step 2: Run tests to verify failure**

Run:

```bash
bin/rails test test/lib/ayaya_contract/runner_test.rb
```

Expected: FAIL with `uninitialized constant AyayaContract`.

- [ ] **Step 3: Implement manifest loader**

Create `lib/ayaya_contract/manifest_loader.rb`:

```ruby
require "yaml"

module AyayaContract
  class ManifestLoader
    def self.load_file(path)
      YAML.safe_load_file(path, aliases: false)
    end
  end
end
```

- [ ] **Step 4: Implement runner**

Create `lib/ayaya_contract/runner.rb`:

```ruby
module AyayaContract
  class Runner
    Result = Struct.new(:success?, :errors, keyword_init: true)

    CRITICAL_FIELDS = [
      %w[identity module_key],
      %w[identity name],
      %w[identity version],
      %w[protocol adapter_protocol_version],
      %w[protocol capabilities],
      %w[routes],
      %w[access default_policy]
    ].freeze

    def initialize(package_manifest:, runtime_manifest:)
      @package_manifest = package_manifest
      @runtime_manifest = runtime_manifest
      @errors = []
    end

    def call
      validate_manifest("package", package_manifest)
      validate_manifest("runtime", runtime_manifest)
      compare_critical_fields if errors.empty?
      Result.new(success?: errors.empty?, errors:)
    end

    private

    attr_reader :package_manifest, :runtime_manifest, :errors

    def validate_manifest(label, manifest)
      result = AdapterProtocol::ManifestValidator.call(manifest)
      result.errors.each { |error| errors << "#{label}: #{error}" }
    end

    def compare_critical_fields
      CRITICAL_FIELDS.each do |path|
        package_value = package_manifest.dig(*path)
        runtime_value = runtime_manifest.dig(*path)
        errors << "critical field mismatch: #{path.join(".")}" unless package_value == runtime_value
      end
    end
  end
end
```

- [ ] **Step 5: Add executable command**

Create `bin/ayaya-contract`:

```ruby
#!/usr/bin/env ruby

require_relative "../config/environment"
require "json"
require "net/http"
require_relative "../lib/ayaya_contract/manifest_loader"
require_relative "../lib/ayaya_contract/runner"

args = ARGV.each_slice(2).to_h
module_yml = args.fetch("--module-yml")
adapter_url = args.fetch("--adapter-url")
adapter_secret = args.fetch("--adapter-secret")

package_manifest = AyayaContract::ManifestLoader.load_file(module_yml)
runtime_manifest = AdapterProtocol::Client.new(adapter_url:, adapter_secret:).manifest
result = AyayaContract::Runner.new(package_manifest:, runtime_manifest:).call

if result.success?
  puts "Ayaya contract: PASS"
  exit 0
else
  puts "Ayaya contract: FAIL"
  result.errors.each { |error| puts "- #{error}" }
  exit 1
end
```

Run:

```bash
chmod +x bin/ayaya-contract
```

- [ ] **Step 6: Ensure lib files autoload**

If Rails does not autoload `lib/ayaya_contract`, add to `config/application.rb`:

```ruby
config.autoload_paths << Rails.root.join("lib")
config.eager_load_paths << Rails.root.join("lib")
```

- [ ] **Step 7: Run tests**

Run:

```bash
bin/rails test test/lib/ayaya_contract/runner_test.rb
```

Expected: PASS.

- [ ] **Step 8: Commit**

Run:

```bash
git add bin/ayaya-contract lib/ayaya_contract test/lib/ayaya_contract config/application.rb
git commit -m "feat: add module contract test harness"
```

---

### Task 11: Add Static NGINX Example And Operational Notes

**Files:**
- Create: `deploy/nginx/ayaya.example.conf`
- Modify: `docs/core_foundation.md`
- Test: `nginx -t -c` if NGINX is installed locally.

**Interfaces:**
- Consumes: `/internal/auth/module_access` endpoint from Task 8.
- Produces: deployable reference for static module routing and trusted header injection.

- [ ] **Step 1: Create NGINX example**

Create `deploy/nginx/ayaya.example.conf`:

```nginx
server {
  listen 80;
  server_name ayaya.local;

  location / {
    proxy_pass http://ayaya_core:3000;
    proxy_set_header Host $host;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
  }

  location = /internal/auth/module_access {
    internal;
    proxy_pass http://ayaya_core:3000/internal/auth/module_access;
    proxy_pass_request_body off;
    proxy_set_header Content-Length "";
    proxy_set_header X-Original-URI $request_uri;
    proxy_set_header Cookie $http_cookie;
  }

  location /m/notes {
    auth_request /internal/auth/module_access;

    auth_request_set $ayaya_user_id $upstream_http_x_ayaya_user_id;
    auth_request_set $ayaya_user_email $upstream_http_x_ayaya_user_email;
    auth_request_set $ayaya_user_display_name $upstream_http_x_ayaya_user_display_name;
    auth_request_set $ayaya_user_role $upstream_http_x_ayaya_user_role;
    auth_request_set $ayaya_module_key $upstream_http_x_ayaya_module_key;
    auth_request_set $ayaya_request_id $upstream_http_x_ayaya_request_id;

    proxy_set_header X-Ayaya-User-Id $ayaya_user_id;
    proxy_set_header X-Ayaya-User-Email $ayaya_user_email;
    proxy_set_header X-Ayaya-User-Display-Name $ayaya_user_display_name;
    proxy_set_header X-Ayaya-User-Role $ayaya_user_role;
    proxy_set_header X-Ayaya-Module-Key $ayaya_module_key;
    proxy_set_header X-Ayaya-Request-Id $ayaya_request_id;

    proxy_set_header X-Ayaya-Client-Header-Guard "";
    proxy_pass http://notes_app:3000;
  }
}
```

- [ ] **Step 2: Document NGINX header rule**

Append to `docs/core_foundation.md`:

```markdown
## NGINX Static Routing

NGINX owns static module routing in v1.

Before proxying to a Module App, NGINX must call `/internal/auth/module_access` through `auth_request`.

NGINX must not trust incoming client-provided `X-Ayaya-*` headers. The example config sets platform headers from Core auth response values only.

Module App ports must remain internal and must not be publicly exposed.
```

- [ ] **Step 3: Validate config if NGINX is available**

Run:

```bash
nginx -t -c "$PWD/deploy/nginx/ayaya.example.conf"
```

Expected if NGINX is installed: syntax is ok.

If NGINX is not installed, record that this validation was not run in the task completion notes.

- [ ] **Step 4: Run Rails tests**

Run:

```bash
bin/rails test
```

Expected: PASS.

- [ ] **Step 5: Commit**

Run:

```bash
git add deploy/nginx/ayaya.example.conf docs/core_foundation.md
git commit -m "docs: add static nginx routing example"
```

---

### Task 12: Final Verification For Core Foundation

**Files:**
- Modify: `docs/core_foundation.md`
- Test: full test suite and route inspection.

**Interfaces:**
- Consumes: all previous tasks.
- Produces: verified Core foundation ready for the `notes` reference module plan.

- [ ] **Step 1: Run full test suite**

Run:

```bash
bin/rails test
```

Expected: PASS.

- [ ] **Step 2: Inspect routes**

Run:

```bash
bin/rails routes | grep -E "admin|users|internal/auth/module_access|root"
```

Expected: routes exist for Devise, ActiveAdmin, root, and internal module access.

- [ ] **Step 3: Check architecture docs are still consistent**

Run:

```bash
grep -R "Sinatra\\|iframe\\|Kafka is selected\\|Core deploys modules" docs app config test
```

Expected: no results except intentional statements saying these are out of scope or not used in v1.

- [ ] **Step 4: Update operational notes**

Append to `docs/core_foundation.md`:

```markdown
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
```

- [ ] **Step 5: Commit**

Run:

```bash
git add docs/core_foundation.md
git commit -m "docs: verify core foundation slice"
```

---

## Self-Review Checklist

- Spec coverage: This plan covers Core Rails foundation, Devise, ActiveAdmin, module registry, manifest validation, adapter client, status/manifest service layer, `auth_request`, trusted headers, static NGINX example, and contract-test harness.
- Deliberate gaps: `notes` reference module, runtime service-to-service calls, events, deployer, and shared integrations are separate future plans.
- Placeholder scan: no task depends on an undefined future implementation.
- Type consistency: `RegisteredModule#accessible_by?(user)`, `AdapterProtocol::ManifestValidator.call`, `AdapterProtocol::Client#manifest`, `AdapterProtocol::Client#status`, and `Modules::RegisterAdapter.call` are defined before use by later tasks.

