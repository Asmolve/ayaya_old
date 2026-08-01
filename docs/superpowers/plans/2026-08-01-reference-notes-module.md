# Reference Notes Module Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the first Ayaya reference module, `notes`, as an independent Rails Module App plus FastAPI Adapter behind Core, NGINX, trusted headers, and a separate PostgreSQL database.

**Architecture:** `notes_app` owns UI, local users, notes, authorization, migrations, and database access. `notes_adapter` owns the Adapter Protocol v1 endpoints and reads `modules/notes/module.yml` as package truth; it obtains runtime status from a protected internal endpoint in `notes_app`. Root Compose runs Core, NGINX, PostgreSQL, `notes_app`, and `notes_adapter`; registration in Core remains manual.

**Tech Stack:** Ruby 3.4.4, Rails 8.1.x, PostgreSQL 16, Python 3.12, FastAPI, Pydantic, Pytest, Docker Compose, NGINX, Minitest.

## Global Constraints

- `notes` lives under `modules/notes/` as an independent module bundle.
- `notes_app` is a standalone Rails app under `modules/notes/app`.
- `notes_adapter` is a standalone FastAPI app under `modules/notes/adapter`.
- `module_key` is `notes` and must remain immutable.
- Module UI route is `/m/notes`.
- Module database is `ayaya_mod_notes`.
- Core must not connect to `ayaya_mod_notes`.
- `notes_adapter` must not connect to `ayaya_mod_notes`; it asks `notes_app` for internal status.
- Adapter endpoints require `Authorization: Bearer <NOTES_ADAPTER_SECRET>`.
- `notes_app` internal status requires `Authorization: Bearer <NOTES_INTERNAL_STATUS_SECRET>`.
- `notes_app` trusts `X-Ayaya-*` headers only because it is internal and reached through NGINX.
- Missing `X-Ayaya-User-Id` returns `401 Unauthorized`.
- Wrong `X-Ayaya-Module-Key` returns `401 Unauthorized`.
- Users can access only their own notes.
- Automatic migrations on `notes_app` startup are forbidden.
- Core registration stays manual.
- Root Compose is the development orchestration entry point.
- Keep all new manifest and JSON field names in `snake_case`.
- Do not add tags, search, markdown, sharing, attachments, background jobs, public notes API, auto-registration, dynamic NGINX generation, or module-to-module communication.

---

## File Structure

- Create `modules/notes/module.yml`: package truth manifest for `notes`.
- Create `modules/notes/compose.yml`: module bundle documentation for module-owned services and commands.
- Create `modules/notes/docs/README.md`: operational setup and local development notes.
- Create `modules/notes/docs/CONTRACT.md`: module-specific contract notes and invariants.
- Create `modules/notes/app/`: standalone Rails Module App.
- Create `modules/notes/app/app/controllers/concerns/ayaya_identity.rb`: trusted header extraction and lazy local user setup.
- Create `modules/notes/app/app/controllers/notes_controller.rb`: note CRUD UI under `/m/notes`.
- Create `modules/notes/app/app/controllers/internal/ayaya/status_controller.rb`: protected internal status endpoint for the adapter.
- Create `modules/notes/app/app/models/local_user.rb`: local user snapshot keyed by Core user id.
- Create `modules/notes/app/app/models/note.rb`: note domain model owned by local user.
- Create `modules/notes/app/test/controllers/notes_controller_test.rb`: missing header, wrong module key, CRUD, and ownership tests.
- Create `modules/notes/app/test/controllers/internal/ayaya/status_controller_test.rb`: internal status secret and shape tests.
- Create `modules/notes/app/test/models/local_user_test.rb`: local user validations.
- Create `modules/notes/app/test/models/note_test.rb`: note validations and ownership association.
- Create `modules/notes/adapter/`: standalone FastAPI Adapter.
- Create `modules/notes/adapter/app/main.py`: FastAPI app and route registration.
- Create `modules/notes/adapter/app/auth.py`: adapter bearer-token dependency.
- Create `modules/notes/adapter/app/settings.py`: environment and path settings.
- Create `modules/notes/adapter/app/manifest.py`: `module.yml` loading and validation.
- Create `modules/notes/adapter/app/status_client.py`: internal status call to `notes_app`.
- Create `modules/notes/adapter/tests/`: Pytest suite for adapter endpoints and status mapping.
- Modify `compose.yml`: add `notes_app` and `notes_adapter` services.
- Modify `deploy/nginx/ayaya.example.conf`: ensure `/m/notes` proxies to `notes_app` and does not expose internal status.
- Modify `README.md`: document `notes` setup, explicit DB prepare, and manual registration.
- Modify `docs/core_foundation.md`: document validated reference module flow.
- Modify `test/lib/ayaya_contract/runner_test.rb` and `lib/ayaya_contract/runner.rb`: extend contract checks only where the current harness lacks required `notes` contract coverage.

## Task 1: Module Bundle Skeleton And Manifest

**Files:**
- Create: `modules/notes/module.yml`
- Create: `modules/notes/compose.yml`
- Create: `modules/notes/docs/README.md`
- Create: `modules/notes/docs/CONTRACT.md`
- Test: `bin/ayaya-contract --module-yml modules/notes/module.yml --adapter-url http://127.0.0.1:1 --adapter-secret unused` is not used yet because the adapter does not exist.
- Test: `bin/rails runner 'puts AyayaContract::ManifestLoader.load_file("modules/notes/module.yml").dig("identity", "module_key")'`

**Interfaces:**
- Consumes: `AyayaContract::ManifestLoader.load_file(path)` from Core.
- Produces: `modules/notes/module.yml` with critical fields later consumed by `notes_adapter` and contract tests.

- [ ] **Step 1: Create manifest first**

Create `modules/notes/module.yml`:

```yaml
identity:
  module_key: notes
  name: Notes
  version: 0.1.0

protocol:
  adapter_protocol_version: "1.0"
  capabilities:
    - manifest.v1
    - health.v1
    - status.v1

presentation:
  description: Personal notes
  icon: file-text
  category: productivity

routes:
  ui_base_path: /m/notes
  api_base_path: /m/notes/api

access:
  default_policy: authenticated
```

- [ ] **Step 2: Verify manifest parses through existing Core loader**

Run:

```bash
bin/rails runner 'puts AyayaContract::ManifestLoader.load_file("modules/notes/module.yml").dig("identity", "module_key")'
```

Expected:

```text
notes
```

- [ ] **Step 3: Add module bundle compose documentation**

Create `modules/notes/compose.yml`:

```yaml
services:
  notes_app:
    build:
      context: ./app
    environment:
      DATABASE_HOST: postgres
      DATABASE_PORT: 5432
      DATABASE_USERNAME: ayaya
      DATABASE_PASSWORD: ayaya
      DATABASE_NAME: ayaya_mod_notes
      NOTES_INTERNAL_STATUS_SECRET: development-notes-internal-status-secret

  notes_adapter:
    build:
      context: ./adapter
    environment:
      NOTES_ADAPTER_SECRET: development-notes-adapter-secret
      NOTES_INTERNAL_STATUS_SECRET: development-notes-internal-status-secret
      NOTES_APP_INTERNAL_STATUS_URL: http://notes_app:3000/internal/ayaya/status
      NOTES_MODULE_YML: /module/module.yml
```

- [ ] **Step 4: Add module docs**

Create `modules/notes/docs/README.md` with:

```markdown
# Notes Module

`notes` is Ayaya's first reference module.

## Services

- `notes_app`: Rails Module App for `/m/notes`
- `notes_adapter`: FastAPI Adapter Protocol service
- Database: `ayaya_mod_notes`

## Development

Prepare the database explicitly:

```bash
docker compose run --rm notes_app bin/rails db:prepare
```

Start the platform:

```bash
docker compose up --build
```

Registration in Core is manual.
```
```

Create `modules/notes/docs/CONTRACT.md` with:

```markdown
# Notes Contract

Core communicates only with `notes_adapter`.

User traffic reaches `notes_app` only through platform NGINX at `/m/notes`.

`notes_app` requires `X-Ayaya-User-Id` and `X-Ayaya-Module-Key: notes`.

`notes_adapter` reads `../module.yml` as package truth and requires `Authorization: Bearer <NOTES_ADAPTER_SECRET>`.

`notes_adapter` obtains runtime status from `notes_app` through `/internal/ayaya/status` using `NOTES_INTERNAL_STATUS_SECRET`.
```

- [ ] **Step 5: Run manifest validation through Core validator**

Run:

```bash
bin/rails runner 'manifest = AyayaContract::ManifestLoader.load_file("modules/notes/module.yml"); result = AdapterProtocol::ManifestValidator.call(manifest); abort(result.errors.join("\n")) unless result.valid?; puts "manifest valid"'
```

Expected:

```text
manifest valid
```

- [ ] **Step 6: Commit**

```bash
git add modules/notes/module.yml modules/notes/compose.yml modules/notes/docs/README.md modules/notes/docs/CONTRACT.md
git commit -m "Add notes module bundle manifest"
```

Do not commit if the user has explicitly asked to batch commits.

## Task 2: Scaffold Standalone Notes Rails App

**Files:**
- Create: `modules/notes/app/`
- Modify: `modules/notes/app/config/database.yml`
- Modify: `modules/notes/app/config/routes.rb`
- Modify: `modules/notes/app/config/environments/development.rb`
- Test: `modules/notes/app/bin/rails test`

**Interfaces:**
- Consumes: PostgreSQL env vars `DATABASE_HOST`, `DATABASE_PORT`, `DATABASE_USERNAME`, `DATABASE_PASSWORD`, `DATABASE_NAME`, `DATABASE_TEST_NAME`.
- Produces: Rails app listening on internal port `3000` and routing under `/m/notes`.

- [ ] **Step 1: Scaffold the Rails app**

Run:

```bash
rails new modules/notes/app \
  --database=postgresql \
  --skip-kamal \
  --skip-thruster \
  --skip-solid \
  --skip-action-mailbox \
  --skip-active-storage \
  --skip-action-text \
  --skip-action-cable \
  --skip-javascript \
  --skip-hotwire \
  --skip-system-test
```

If local `rails` is unavailable, run the same command through a Ruby Docker image using the Rails version compatible with the root app.

- [ ] **Step 2: Configure database env support**

Edit `modules/notes/app/config/database.yml` so `default` includes:

```yaml
default: &default
  adapter: postgresql
  encoding: unicode
  pool: <%= ENV.fetch("RAILS_MAX_THREADS") { 5 } %>
  host: <%= ENV["DATABASE_HOST"] %>
  port: <%= ENV["DATABASE_PORT"] %>
  username: <%= ENV["DATABASE_USERNAME"] %>
  password: <%= ENV["DATABASE_PASSWORD"] %>
```

Set development and test database names:

```yaml
development:
  <<: *default
  database: <%= ENV.fetch("DATABASE_NAME") { "ayaya_mod_notes" } %>

test:
  <<: *default
  database: <%= ENV.fetch("DATABASE_TEST_NAME") { "ayaya_mod_notes_test" } %>
```

- [ ] **Step 3: Configure route prefix**

Edit `modules/notes/app/config/routes.rb`:

```ruby
Rails.application.routes.draw do
  scope "/m/notes" do
    root "notes#index", as: :notes_root
    resources :notes
  end

  namespace :internal do
    namespace :ayaya do
      get "status", to: "status#show"
    end
  end

  get "up" => "rails/health#show", as: :rails_health_check
end
```

- [ ] **Step 4: Allow compose hostnames in development**

Edit `modules/notes/app/config/environments/development.rb`:

```ruby
ENV.fetch("AYAYA_ALLOWED_HOSTS", "").split(",").map(&:strip).reject(&:empty?).each do |host|
  config.hosts << host
end
```

- [ ] **Step 5: Verify scaffold baseline**

Run:

```bash
cd modules/notes/app
bin/rails test
```

Expected:

```text
0 failures, 0 errors
```

- [ ] **Step 6: Commit**

```bash
git add modules/notes/app
git commit -m "Scaffold notes Rails app"
```

Do not commit if the user has explicitly asked to batch commits.

## Task 3: Trusted Header Identity And Local Users

**Files:**
- Create: `modules/notes/app/app/controllers/concerns/ayaya_identity.rb`
- Create: `modules/notes/app/app/models/local_user.rb`
- Create: `modules/notes/app/db/migrate/*_create_local_users.rb`
- Create: `modules/notes/app/test/controllers/ayaya_identity_test.rb`
- Create: `modules/notes/app/test/models/local_user_test.rb`
- Modify: `modules/notes/app/app/controllers/application_controller.rb`

**Interfaces:**
- Consumes request headers `X-Ayaya-User-Id`, `X-Ayaya-User-Email`, `X-Ayaya-User-Display-Name`, `X-Ayaya-User-Role`, `X-Ayaya-Module-Key`, `X-Ayaya-Request-Id`.
- Produces controller helper `current_local_user` returning a `LocalUser`.

- [ ] **Step 1: Write failing model test**

Create `modules/notes/app/test/models/local_user_test.rb`:

```ruby
require "test_helper"

class LocalUserTest < ActiveSupport::TestCase
  test "requires unique core user id" do
    LocalUser.create!(core_user_id: "1", email: "one@example.test")
    duplicate = LocalUser.new(core_user_id: "1", email: "two@example.test")

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:core_user_id], "has already been taken"
  end
end
```

- [ ] **Step 2: Run test and verify it fails**

Run:

```bash
cd modules/notes/app
bin/rails test test/models/local_user_test.rb
```

Expected: FAIL with `uninitialized constant LocalUser`.

- [ ] **Step 3: Implement local users**

Generate:

```bash
cd modules/notes/app
bin/rails generate model LocalUser core_user_id:string:uniq email:string display_name:string global_role:string last_seen_at:datetime
```

Edit `modules/notes/app/app/models/local_user.rb`:

```ruby
class LocalUser < ApplicationRecord
  has_many :notes, dependent: :destroy

  validates :core_user_id, presence: true, uniqueness: true
end
```

- [ ] **Step 4: Run model test**

Run:

```bash
cd modules/notes/app
bin/rails db:test:prepare test/models/local_user_test.rb
```

Expected: PASS.

- [ ] **Step 5: Write failing identity controller test**

Create `modules/notes/app/test/controllers/ayaya_identity_test.rb`:

```ruby
require "test_helper"

class AyayaIdentityTest < ActionDispatch::IntegrationTest
  test "rejects missing platform user header" do
    get "/m/notes"

    assert_response :unauthorized
  end

  test "rejects wrong module key" do
    get "/m/notes", headers: {
      "X-Ayaya-User-Id" => "1",
      "X-Ayaya-Module-Key" => "wrong"
    }

    assert_response :unauthorized
  end

  test "creates and refreshes local user from trusted headers" do
    freeze_time do
      get "/m/notes", headers: {
        "X-Ayaya-User-Id" => "1",
        "X-Ayaya-User-Email" => "user@example.test",
        "X-Ayaya-User-Display-Name" => "User",
        "X-Ayaya-User-Role" => "user",
        "X-Ayaya-Module-Key" => "notes"
      }

      assert_response :success
      local_user = LocalUser.find_by!(core_user_id: "1")
      assert_equal "user@example.test", local_user.email
      assert_equal "User", local_user.display_name
      assert_equal "user", local_user.global_role
      assert_equal Time.current.to_i, local_user.last_seen_at.to_i
    end
  end
end
```

- [ ] **Step 6: Run identity test and verify it fails**

Run:

```bash
cd modules/notes/app
bin/rails test test/controllers/ayaya_identity_test.rb
```

Expected: FAIL because `NotesController` and identity concern do not exist.

- [ ] **Step 7: Implement identity concern**

Create `modules/notes/app/app/controllers/concerns/ayaya_identity.rb`:

```ruby
module AyayaIdentity
  extend ActiveSupport::Concern

  included do
    before_action :require_ayaya_identity
    helper_method :current_local_user
  end

  private

  attr_reader :current_local_user

  def require_ayaya_identity
    return head :unauthorized if request.headers["X-Ayaya-User-Id"].blank?
    return head :unauthorized unless request.headers["X-Ayaya-Module-Key"] == "notes"

    @current_local_user = LocalUser.find_or_initialize_by(core_user_id: request.headers["X-Ayaya-User-Id"])
    current_local_user.email = request.headers["X-Ayaya-User-Email"] if request.headers["X-Ayaya-User-Email"].present?
    current_local_user.display_name = request.headers["X-Ayaya-User-Display-Name"] if request.headers["X-Ayaya-User-Display-Name"].present?
    current_local_user.global_role = request.headers["X-Ayaya-User-Role"] if request.headers["X-Ayaya-User-Role"].present?
    current_local_user.last_seen_at = Time.current
    current_local_user.save!
  end
end
```

Create a temporary `NotesController` for the identity tests:

```ruby
class NotesController < ApplicationController
  include AyayaIdentity

  def index
    render plain: "Notes"
  end
end
```

- [ ] **Step 8: Run identity tests**

Run:

```bash
cd modules/notes/app
bin/rails db:test:prepare test/controllers/ayaya_identity_test.rb test/models/local_user_test.rb
```

Expected: PASS.

- [ ] **Step 9: Commit**

```bash
git add modules/notes/app
git commit -m "Add notes trusted identity"
```

Do not commit if the user has explicitly asked to batch commits.

## Task 4: Notes CRUD With Ownership

**Files:**
- Create: `modules/notes/app/app/models/note.rb`
- Create: `modules/notes/app/db/migrate/*_create_notes.rb`
- Modify: `modules/notes/app/app/controllers/notes_controller.rb`
- Create: `modules/notes/app/app/views/notes/index.html.erb`
- Create: `modules/notes/app/app/views/notes/show.html.erb`
- Create: `modules/notes/app/app/views/notes/new.html.erb`
- Create: `modules/notes/app/app/views/notes/edit.html.erb`
- Create: `modules/notes/app/app/views/notes/_form.html.erb`
- Create: `modules/notes/app/test/models/note_test.rb`
- Create: `modules/notes/app/test/controllers/notes_controller_test.rb`

**Interfaces:**
- Consumes `current_local_user` from `AyayaIdentity`.
- Produces note CRUD UI under `/m/notes/notes` and root list at `/m/notes`.

- [ ] **Step 1: Write failing note model test**

Create `modules/notes/app/test/models/note_test.rb`:

```ruby
require "test_helper"

class NoteTest < ActiveSupport::TestCase
  test "requires owner and title" do
    note = Note.new(body: "Body")

    assert_not note.valid?
    assert_includes note.errors[:local_user], "must exist"
    assert_includes note.errors[:title], "can't be blank"
  end
end
```

- [ ] **Step 2: Run note model test and verify it fails**

Run:

```bash
cd modules/notes/app
bin/rails test test/models/note_test.rb
```

Expected: FAIL with `uninitialized constant Note`.

- [ ] **Step 3: Implement note model**

Generate:

```bash
cd modules/notes/app
bin/rails generate model Note local_user:references title:string body:text
```

Edit `modules/notes/app/app/models/note.rb`:

```ruby
class Note < ApplicationRecord
  belongs_to :local_user

  validates :title, presence: true
end
```

- [ ] **Step 4: Run note model test**

Run:

```bash
cd modules/notes/app
bin/rails db:test:prepare test/models/note_test.rb
```

Expected: PASS.

- [ ] **Step 5: Write failing CRUD ownership tests**

Create `modules/notes/app/test/controllers/notes_controller_test.rb`:

```ruby
require "test_helper"

class NotesControllerTest < ActionDispatch::IntegrationTest
  def ayaya_headers(core_user_id: "1", email: "user@example.test")
    {
      "X-Ayaya-User-Id" => core_user_id,
      "X-Ayaya-User-Email" => email,
      "X-Ayaya-User-Display-Name" => "User #{core_user_id}",
      "X-Ayaya-User-Role" => "user",
      "X-Ayaya-Module-Key" => "notes"
    }
  end

  test "lists only current user's notes" do
    owner = LocalUser.create!(core_user_id: "1")
    other = LocalUser.create!(core_user_id: "2")
    Note.create!(local_user: owner, title: "Mine", body: "Visible")
    Note.create!(local_user: other, title: "Other", body: "Hidden")

    get "/m/notes", headers: ayaya_headers(core_user_id: "1")

    assert_response :success
    assert_includes response.body, "Mine"
    assert_not_includes response.body, "Other"
  end

  test "creates note owned by current local user" do
    assert_difference("Note.count", 1) do
      post "/m/notes/notes", params: { note: { title: "New note", body: "Body" } }, headers: ayaya_headers(core_user_id: "1")
    end

    note = Note.last
    assert_equal "1", note.local_user.core_user_id
    assert_redirected_to "/m/notes/notes/#{note.id}"
  end

  test "does not show another user's note" do
    other = LocalUser.create!(core_user_id: "2")
    note = Note.create!(local_user: other, title: "Other", body: "Hidden")

    get "/m/notes/notes/#{note.id}", headers: ayaya_headers(core_user_id: "1")

    assert_response :not_found
  end

  test "updates only own note" do
    owner = LocalUser.create!(core_user_id: "1")
    note = Note.create!(local_user: owner, title: "Old", body: "Body")

    patch "/m/notes/notes/#{note.id}", params: { note: { title: "New", body: "Updated" } }, headers: ayaya_headers(core_user_id: "1")

    assert_redirected_to "/m/notes/notes/#{note.id}"
    assert_equal "New", note.reload.title
  end

  test "does not delete another user's note" do
    other = LocalUser.create!(core_user_id: "2")
    note = Note.create!(local_user: other, title: "Other", body: "Hidden")

    assert_no_difference("Note.count") do
      delete "/m/notes/notes/#{note.id}", headers: ayaya_headers(core_user_id: "1")
    end

    assert_response :not_found
  end
end
```

- [ ] **Step 6: Run CRUD tests and verify they fail**

Run:

```bash
cd modules/notes/app
bin/rails test test/controllers/notes_controller_test.rb
```

Expected: FAIL because controller actions and views are incomplete.

- [ ] **Step 7: Implement controller**

Replace `modules/notes/app/app/controllers/notes_controller.rb`:

```ruby
class NotesController < ApplicationController
  include AyayaIdentity

  before_action :set_note, only: %i[show edit update destroy]

  def index
    @notes = current_local_user.notes.order(updated_at: :desc)
  end

  def show
  end

  def new
    @note = current_local_user.notes.build
  end

  def create
    @note = current_local_user.notes.build(note_params)

    if @note.save
      redirect_to note_path(@note)
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @note.update(note_params)
      redirect_to note_path(@note)
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @note.destroy!
    redirect_to notes_root_path
  end

  private

  def set_note
    @note = current_local_user.notes.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    head :not_found
  end

  def note_params
    params.require(:note).permit(:title, :body)
  end
end
```

- [ ] **Step 8: Implement simple Rails views**

Create `modules/notes/app/app/views/notes/index.html.erb`:

```erb
<main>
  <header>
    <h1>Notes</h1>
    <%= link_to "New note", new_note_path %>
  </header>

  <% if @notes.any? %>
    <ul>
      <% @notes.each do |note| %>
        <li><%= link_to note.title, note_path(note) %></li>
      <% end %>
    </ul>
  <% else %>
    <p>No notes yet.</p>
  <% end %>
</main>
```

Create `_form`, `show`, `new`, and `edit` with `form_with model: @note`, title field, body textarea, Save button, Back links, Edit link, and Delete button.

- [ ] **Step 9: Run CRUD tests**

Run:

```bash
cd modules/notes/app
bin/rails db:test:prepare test/controllers/notes_controller_test.rb test/models/note_test.rb
```

Expected: PASS.

- [ ] **Step 10: Run full notes app tests**

Run:

```bash
cd modules/notes/app
bin/rails test
```

Expected: PASS.

- [ ] **Step 11: Commit**

```bash
git add modules/notes/app
git commit -m "Add notes CRUD module app"
```

Do not commit if the user has explicitly asked to batch commits.

## Task 5: Protected Internal Status Endpoint In Notes App

**Files:**
- Create: `modules/notes/app/app/controllers/internal/ayaya/status_controller.rb`
- Create: `modules/notes/app/test/controllers/internal/ayaya/status_controller_test.rb`
- Modify: `modules/notes/app/config/routes.rb`

**Interfaces:**
- Consumes env var `NOTES_INTERNAL_STATUS_SECRET`.
- Produces `GET /internal/ayaya/status` JSON for `notes_adapter`.

- [ ] **Step 1: Write failing status controller tests**

Create `modules/notes/app/test/controllers/internal/ayaya/status_controller_test.rb`:

```ruby
require "test_helper"

class Internal::Ayaya::StatusControllerTest < ActionDispatch::IntegrationTest
  setup do
    @old_secret = ENV["NOTES_INTERNAL_STATUS_SECRET"]
    ENV["NOTES_INTERNAL_STATUS_SECRET"] = "test-internal-secret"
  end

  teardown do
    ENV["NOTES_INTERNAL_STATUS_SECRET"] = @old_secret
  end

  test "requires internal status secret" do
    get "/internal/ayaya/status"

    assert_response :unauthorized
  end

  test "returns healthy status when database is available" do
    get "/internal/ayaya/status", headers: { "Authorization" => "Bearer test-internal-secret" }

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal "notes", body.fetch("module_key")
    assert_equal "healthy", body.fetch("runtime_status")
    assert_equal "healthy", body.fetch("components").fetch("app")
    assert_equal "healthy", body.fetch("components").fetch("database")
  end
end
```

- [ ] **Step 2: Run status tests and verify they fail**

Run:

```bash
cd modules/notes/app
bin/rails test test/controllers/internal/ayaya/status_controller_test.rb
```

Expected: FAIL with missing controller.

- [ ] **Step 3: Implement status controller**

Create `modules/notes/app/app/controllers/internal/ayaya/status_controller.rb`:

```ruby
module Internal
  module Ayaya
    class StatusController < ApplicationController
      skip_forgery_protection
      before_action :require_internal_secret

      def show
        ActiveRecord::Base.connection.execute("SELECT 1")

        render json: {
          module_key: "notes",
          runtime_status: "healthy",
          components: {
            app: "healthy",
            database: "healthy"
          },
          checked_at: Time.current.utc.iso8601,
          degraded_reasons: []
        }
      rescue ActiveRecord::ActiveRecordError
        render json: {
          module_key: "notes",
          runtime_status: "unhealthy",
          components: {
            app: "healthy",
            database: "unhealthy"
          },
          checked_at: Time.current.utc.iso8601,
          degraded_reasons: [ "database_unavailable" ]
        }, status: :service_unavailable
      end

      private

      def require_internal_secret
        expected = ENV.fetch("NOTES_INTERNAL_STATUS_SECRET", "")
        token = request.authorization.to_s.delete_prefix("Bearer ")
        head :unauthorized unless expected.present? && ActiveSupport::SecurityUtils.secure_compare(token, expected)
      end
    end
  end
end
```

- [ ] **Step 4: Run status tests**

Run:

```bash
cd modules/notes/app
bin/rails db:test:prepare test/controllers/internal/ayaya/status_controller_test.rb
```

Expected: PASS.

- [ ] **Step 5: Run full notes app tests**

Run:

```bash
cd modules/notes/app
bin/rails test
```

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add modules/notes/app
git commit -m "Add notes internal status endpoint"
```

Do not commit if the user has explicitly asked to batch commits.

## Task 6: FastAPI Adapter Skeleton And Authenticated Manifest

**Files:**
- Create: `modules/notes/adapter/Dockerfile`
- Create: `modules/notes/adapter/requirements.txt`
- Create: `modules/notes/adapter/app/__init__.py`
- Create: `modules/notes/adapter/app/main.py`
- Create: `modules/notes/adapter/app/auth.py`
- Create: `modules/notes/adapter/app/settings.py`
- Create: `modules/notes/adapter/app/manifest.py`
- Create: `modules/notes/adapter/tests/test_manifest.py`

**Interfaces:**
- Consumes `NOTES_ADAPTER_SECRET`.
- Consumes `NOTES_MODULE_YML`.
- Produces `GET /ayaya/manifest`.

- [ ] **Step 1: Create adapter dependency files**

Create `modules/notes/adapter/requirements.txt`:

```text
fastapi==0.116.1
httpx==0.28.1
pydantic==2.11.7
pytest==8.4.1
PyYAML==6.0.2
uvicorn[standard]==0.35.0
```

Create `modules/notes/adapter/Dockerfile`:

```dockerfile
FROM python:3.12-slim

WORKDIR /adapter

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY app ./app

EXPOSE 8080
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8080"]
```

- [ ] **Step 2: Write failing manifest auth tests**

Create `modules/notes/adapter/tests/test_manifest.py`:

```python
from pathlib import Path

from fastapi.testclient import TestClient

from app.main import create_app


def write_manifest(path: Path) -> None:
    path.write_text(
        """
identity:
  module_key: notes
  name: Notes
  version: 0.1.0
protocol:
  adapter_protocol_version: "1.0"
  capabilities:
    - manifest.v1
    - health.v1
    - status.v1
routes:
  ui_base_path: /m/notes
  api_base_path: /m/notes/api
access:
  default_policy: authenticated
""".strip(),
        encoding="utf-8",
    )


def test_manifest_requires_adapter_secret(tmp_path, monkeypatch):
    manifest_path = tmp_path / "module.yml"
    write_manifest(manifest_path)
    monkeypatch.setenv("NOTES_MODULE_YML", str(manifest_path))
    monkeypatch.setenv("NOTES_ADAPTER_SECRET", "secret")

    client = TestClient(create_app())

    response = client.get("/ayaya/manifest")

    assert response.status_code == 401


def test_manifest_returns_module_yml(tmp_path, monkeypatch):
    manifest_path = tmp_path / "module.yml"
    write_manifest(manifest_path)
    monkeypatch.setenv("NOTES_MODULE_YML", str(manifest_path))
    monkeypatch.setenv("NOTES_ADAPTER_SECRET", "secret")

    client = TestClient(create_app())

    response = client.get("/ayaya/manifest", headers={"Authorization": "Bearer secret"})

    assert response.status_code == 200
    assert response.json()["identity"]["module_key"] == "notes"
```

- [ ] **Step 3: Run tests and verify they fail**

Run:

```bash
cd modules/notes/adapter
python -m pytest tests/test_manifest.py
```

Expected: FAIL because `app.main` does not exist.

- [ ] **Step 4: Implement settings, auth, manifest, and app**

Create `modules/notes/adapter/app/settings.py`:

```python
from functools import lru_cache
from pydantic import BaseModel
import os


class Settings(BaseModel):
    adapter_secret: str
    module_yml: str
    notes_app_internal_status_url: str = "http://notes_app:3000/internal/ayaya/status"
    internal_status_secret: str = ""


@lru_cache
def get_settings() -> Settings:
    return Settings(
        adapter_secret=os.environ.get("NOTES_ADAPTER_SECRET", ""),
        module_yml=os.environ.get("NOTES_MODULE_YML", "../module.yml"),
        notes_app_internal_status_url=os.environ.get(
            "NOTES_APP_INTERNAL_STATUS_URL",
            "http://notes_app:3000/internal/ayaya/status",
        ),
        internal_status_secret=os.environ.get("NOTES_INTERNAL_STATUS_SECRET", ""),
    )
```

Create `modules/notes/adapter/app/auth.py`:

```python
from fastapi import Depends, Header, HTTPException

from .settings import Settings, get_settings


def require_adapter_secret(
    authorization: str | None = Header(default=None),
    settings: Settings = Depends(get_settings),
) -> None:
    expected = f"Bearer {settings.adapter_secret}"
    if not settings.adapter_secret or authorization != expected:
        raise HTTPException(status_code=401, detail="Unauthorized")
```

Create `modules/notes/adapter/app/manifest.py`:

```python
from pathlib import Path
from typing import Any

import yaml


def load_manifest(path: str) -> dict[str, Any]:
    with Path(path).open("r", encoding="utf-8") as file:
        loaded = yaml.safe_load(file)
    if not isinstance(loaded, dict):
        raise ValueError("module.yml must contain a mapping")
    return loaded
```

Create `modules/notes/adapter/app/main.py`:

```python
from fastapi import Depends, FastAPI

from .auth import require_adapter_secret
from .manifest import load_manifest
from .settings import Settings, get_settings


def create_app() -> FastAPI:
    app = FastAPI(title="Ayaya Notes Adapter")

    @app.get("/ayaya/manifest", dependencies=[Depends(require_adapter_secret)])
    def manifest(settings: Settings = Depends(get_settings)):
        return load_manifest(settings.module_yml)

    return app


app = create_app()
```

- [ ] **Step 5: Run manifest tests**

Run:

```bash
cd modules/notes/adapter
python -m pytest tests/test_manifest.py
```

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add modules/notes/adapter
git commit -m "Add notes adapter manifest endpoint"
```

Do not commit if the user has explicitly asked to batch commits.

## Task 7: FastAPI Adapter Health, Readiness, And Status Mapping

**Files:**
- Modify: `modules/notes/adapter/app/main.py`
- Create: `modules/notes/adapter/app/status_client.py`
- Create: `modules/notes/adapter/tests/test_health_status.py`

**Interfaces:**
- Consumes `NOTES_APP_INTERNAL_STATUS_URL`.
- Consumes `NOTES_INTERNAL_STATUS_SECRET`.
- Produces `GET /ayaya/health/live`, `GET /ayaya/health/ready`, and `GET /ayaya/status`.

- [ ] **Step 1: Write failing health/status tests**

Create `modules/notes/adapter/tests/test_health_status.py`:

```python
from pathlib import Path

import httpx
from fastapi.testclient import TestClient

from app.main import create_app


def write_manifest(path: Path) -> None:
    path.write_text(
        """
identity:
  module_key: notes
  name: Notes
  version: 0.1.0
protocol:
  adapter_protocol_version: "1.0"
  capabilities:
    - manifest.v1
    - health.v1
    - status.v1
routes:
  ui_base_path: /m/notes
  api_base_path: /m/notes/api
access:
  default_policy: authenticated
""".strip(),
        encoding="utf-8",
    )


def configure(monkeypatch, manifest_path: Path):
    monkeypatch.setenv("NOTES_MODULE_YML", str(manifest_path))
    monkeypatch.setenv("NOTES_ADAPTER_SECRET", "secret")
    monkeypatch.setenv("NOTES_INTERNAL_STATUS_SECRET", "internal")
    monkeypatch.setenv("NOTES_APP_INTERNAL_STATUS_URL", "http://notes-app/internal/ayaya/status")


def test_live_requires_adapter_secret(tmp_path, monkeypatch):
    manifest_path = tmp_path / "module.yml"
    write_manifest(manifest_path)
    configure(monkeypatch, manifest_path)

    client = TestClient(create_app())

    assert client.get("/ayaya/health/live").status_code == 401


def test_live_returns_ok(tmp_path, monkeypatch):
    manifest_path = tmp_path / "module.yml"
    write_manifest(manifest_path)
    configure(monkeypatch, manifest_path)

    client = TestClient(create_app())

    response = client.get("/ayaya/health/live", headers={"Authorization": "Bearer secret"})

    assert response.status_code == 200
    assert response.json() == {"status": "ok", "component": "adapter"}


def test_status_maps_notes_app_status(tmp_path, monkeypatch):
    manifest_path = tmp_path / "module.yml"
    write_manifest(manifest_path)
    configure(monkeypatch, manifest_path)

    def handler(request: httpx.Request) -> httpx.Response:
        assert request.headers["Authorization"] == "Bearer internal"
        return httpx.Response(200, json={
            "module_key": "notes",
            "runtime_status": "healthy",
            "components": {"app": "healthy", "database": "healthy"},
            "checked_at": "2026-08-01T00:00:00Z",
            "degraded_reasons": [],
        })

    transport = httpx.MockTransport(handler)
    app = create_app(status_transport=transport)
    client = TestClient(app)

    response = client.get("/ayaya/status", headers={"Authorization": "Bearer secret"})

    assert response.status_code == 200
    body = response.json()
    assert body["runtime_status"] == "healthy"
    assert body["module_version"] == "0.1.0"
    assert body["adapter_protocol_version"] == "1.0"
    assert body["components"]["database"] == "healthy"


def test_ready_fails_when_notes_app_status_is_unreachable(tmp_path, monkeypatch):
    manifest_path = tmp_path / "module.yml"
    write_manifest(manifest_path)
    configure(monkeypatch, manifest_path)

    def handler(request: httpx.Request) -> httpx.Response:
        raise httpx.ConnectError("unreachable", request=request)

    app = create_app(status_transport=httpx.MockTransport(handler))
    client = TestClient(app)

    response = client.get("/ayaya/health/ready", headers={"Authorization": "Bearer secret"})

    assert response.status_code == 503
    assert response.json()["ready"] is False
```

- [ ] **Step 2: Run health/status tests and verify they fail**

Run:

```bash
cd modules/notes/adapter
python -m pytest tests/test_health_status.py
```

Expected: FAIL because the endpoints and status client do not exist.

- [ ] **Step 3: Implement status client**

Create `modules/notes/adapter/app/status_client.py`:

```python
from typing import Any

import httpx

from .settings import Settings


def fetch_notes_app_status(
    settings: Settings,
    transport: httpx.BaseTransport | None = None,
) -> dict[str, Any]:
    headers = {"Authorization": f"Bearer {settings.internal_status_secret}"}
    with httpx.Client(transport=transport, timeout=2.0) as client:
        response = client.get(settings.notes_app_internal_status_url, headers=headers)
        response.raise_for_status()
        data = response.json()
    if not isinstance(data, dict):
        raise ValueError("notes app status must be an object")
    return data
```

- [ ] **Step 4: Implement health/status endpoints**

Modify `create_app` signature in `modules/notes/adapter/app/main.py`:

```python
def create_app(status_transport=None) -> FastAPI:
```

Add endpoints:

```python
from datetime import datetime, timezone
import httpx

from .status_client import fetch_notes_app_status


@app.get("/ayaya/health/live", dependencies=[Depends(require_adapter_secret)])
def live():
    return {"status": "ok", "component": "adapter"}


@app.get("/ayaya/health/ready", dependencies=[Depends(require_adapter_secret)])
def ready(settings: Settings = Depends(get_settings)):
    try:
        load_manifest(settings.module_yml)
        fetch_notes_app_status(settings, transport=status_transport)
        return {"status": "ok", "component": "adapter", "ready": True}
    except Exception:
        return JSONResponse(
            status_code=503,
            content={"status": "error", "component": "adapter", "ready": False},
        )


@app.get("/ayaya/status", dependencies=[Depends(require_adapter_secret)])
def status(settings: Settings = Depends(get_settings)):
    manifest_data = load_manifest(settings.module_yml)
    try:
        app_status = fetch_notes_app_status(settings, transport=status_transport)
        runtime_status = app_status.get("runtime_status", "unhealthy")
        components = app_status.get("components", {})
        checked_at = app_status.get("checked_at") or datetime.now(timezone.utc).isoformat()
        degraded_reasons = app_status.get("degraded_reasons", [])
    except (httpx.HTTPError, ValueError):
        runtime_status = "unreachable"
        components = {"adapter": "healthy", "app": "unreachable", "database": "unknown"}
        checked_at = datetime.now(timezone.utc).isoformat()
        degraded_reasons = ["notes_app_unreachable"]

    components = {"adapter": "healthy", **components}
    return {
        "runtime_status": runtime_status,
        "module_key": manifest_data["identity"]["module_key"],
        "module_version": manifest_data["identity"]["version"],
        "adapter_protocol_version": manifest_data["protocol"]["adapter_protocol_version"],
        "checked_at": checked_at,
        "components": components,
        "degraded_reasons": degraded_reasons,
    }
```

Import `JSONResponse`:

```python
from fastapi.responses import JSONResponse
```

- [ ] **Step 5: Run adapter tests**

Run:

```bash
cd modules/notes/adapter
python -m pytest
```

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add modules/notes/adapter
git commit -m "Add notes adapter health status endpoints"
```

Do not commit if the user has explicitly asked to batch commits.

## Task 8: Root Compose And NGINX Integration

**Files:**
- Modify: `compose.yml`
- Modify: `deploy/nginx/ayaya.example.conf`
- Create: `modules/notes/app/Dockerfile.dev`
- Test: `docker compose config`
- Test: `docker compose build notes_app notes_adapter`
- Test: `docker run --rm -v "$PWD/deploy/nginx/ayaya.example.conf:/etc/nginx/nginx.conf:ro" nginx:1.27-alpine nginx -t`

**Interfaces:**
- Consumes `modules/notes/app` and `modules/notes/adapter` Dockerfiles.
- Produces internal compose services `notes_app` and `notes_adapter`.

- [ ] **Step 1: Add notes app dev Dockerfile**

Create `modules/notes/app/Dockerfile.dev`:

```dockerfile
# syntax=docker/dockerfile:1

ARG RUBY_VERSION=3.4.4
FROM docker.io/library/ruby:$RUBY_VERSION-slim

WORKDIR /rails

RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y build-essential curl git libpq-dev libyaml-dev pkg-config && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

ENV RAILS_ENV=development

COPY Gemfile Gemfile.lock ./
RUN bundle install

COPY . .

EXPOSE 3000
CMD ["./bin/rails", "server", "-b", "0.0.0.0", "-p", "3000"]
```

- [ ] **Step 2: Add services to root compose**

Modify root `compose.yml`:

```yaml
  notes_app:
    build:
      context: ./modules/notes/app
      dockerfile: Dockerfile.dev
    environment:
      RAILS_ENV: development
      DATABASE_HOST: postgres
      DATABASE_PORT: 5432
      DATABASE_USERNAME: ayaya
      DATABASE_PASSWORD: ayaya
      DATABASE_NAME: ayaya_mod_notes
      RAILS_LOG_TO_STDOUT: "true"
      AYAYA_ALLOWED_HOSTS: ayaya.local,localhost,notes_app
      NOTES_INTERNAL_STATUS_SECRET: development-notes-internal-status-secret
    depends_on:
      postgres:
        condition: service_healthy
    command: >
      sh -lc "rm -f tmp/pids/server.pid &&
      bin/rails server -b 0.0.0.0 -p 3000"
    healthcheck:
      test: ["CMD-SHELL", "curl -fsS http://localhost:3000/up >/dev/null"]
      interval: 5s
      timeout: 5s
      retries: 24
    volumes:
      - ./modules/notes/app:/rails
    stdin_open: true
    tty: true

  notes_adapter:
    build:
      context: ./modules/notes/adapter
    environment:
      NOTES_ADAPTER_SECRET: development-notes-adapter-secret
      NOTES_INTERNAL_STATUS_SECRET: development-notes-internal-status-secret
      NOTES_APP_INTERNAL_STATUS_URL: http://notes_app:3000/internal/ayaya/status
      NOTES_MODULE_YML: /module/module.yml
    depends_on:
      notes_app:
        condition: service_healthy
    volumes:
      - ./modules/notes/module.yml:/module/module.yml:ro
```

Do not publish `notes_app` or `notes_adapter` ports to the host.

- [ ] **Step 3: Verify NGINX route remains internal**

Confirm `deploy/nginx/ayaya.example.conf` routes `/m/notes` to:

```nginx
proxy_pass http://$notes_app_upstream:3000;
```

Confirm there is no `location /internal/ayaya/status` route.

- [ ] **Step 4: Run compose config**

Run:

```bash
docker compose config
```

Expected: valid config containing `notes_app` and `notes_adapter`.

- [ ] **Step 5: Run NGINX validation**

Run:

```bash
docker run --rm -v "$PWD/deploy/nginx/ayaya.example.conf:/etc/nginx/nginx.conf:ro" nginx:1.27-alpine nginx -t
```

Expected: syntax is ok, test is successful.

- [ ] **Step 6: Build module services**

Run:

```bash
docker compose build notes_app notes_adapter
```

Expected: both images build.

- [ ] **Step 7: Commit**

```bash
git add compose.yml deploy/nginx/ayaya.example.conf modules/notes/app/Dockerfile.dev
git commit -m "Wire notes module into compose"
```

Do not commit if the user has explicitly asked to batch commits.

## Task 9: Contract Harness Expansion For Notes

**Files:**
- Modify: `lib/ayaya_contract/runner.rb`
- Modify: `bin/ayaya-contract`
- Modify: `test/lib/ayaya_contract/runner_test.rb`
- Create: `test/lib/ayaya_contract/compose_exposure_test.rb`

**Interfaces:**
- Consumes package manifest and runtime manifest.
- Consumes optional compose file path.
- Produces stricter contract failures for route metadata and public module port exposure.

- [ ] **Step 1: Write failing route/default contract tests**

Add to `test/lib/ayaya_contract/runner_test.rb`:

```ruby
test "fails when package route is outside module namespace" do
  package = VALID_MANIFEST.deep_dup
  package["routes"]["ui_base_path"] = "/notes"

  result = AyayaContract::Runner.new(package_manifest: package, runtime_manifest: VALID_MANIFEST).call

  assert_not result.success?
  assert_includes result.errors, "package: routes.ui_base_path must equal /m/notes"
end
```

- [ ] **Step 2: Run test and verify it fails if coverage is missing**

Run:

```bash
bin/rails test test/lib/ayaya_contract/runner_test.rb
```

Expected: FAIL if current validator does not catch the route issue.

- [ ] **Step 3: Add compose exposure test**

Create `test/lib/ayaya_contract/compose_exposure_test.rb`:

```ruby
require "test_helper"
require "yaml"

class AyayaContract::ComposeExposureTest < ActiveSupport::TestCase
  test "notes app and adapter do not publish host ports" do
    compose = YAML.safe_load_file("compose.yml", aliases: true)

    assert_nil compose.dig("services", "notes_app", "ports")
    assert_nil compose.dig("services", "notes_adapter", "ports")
  end
end
```

- [ ] **Step 4: Run compose exposure test and verify it fails before compose task**

Run:

```bash
bin/rails test test/lib/ayaya_contract/compose_exposure_test.rb
```

Expected before Task 8: FAIL because services do not exist. Expected after Task 8: PASS.

- [ ] **Step 5: Add optional CLI compose argument if needed**

If the contract runner needs a CLI path for compose checks, extend `bin/ayaya-contract` to accept:

```text
--compose-yml compose.yml
```

Keep existing usage working:

```bash
bin/ayaya-contract --module-yml modules/notes/module.yml --adapter-url http://notes_adapter:8080 --adapter-secret development-notes-adapter-secret
```

- [ ] **Step 6: Run Core contract tests**

Run:

```bash
bin/rails test test/lib/ayaya_contract/runner_test.rb test/lib/ayaya_contract/compose_exposure_test.rb
```

Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add lib/ayaya_contract bin/ayaya-contract test/lib/ayaya_contract
git commit -m "Expand module contract checks for notes"
```

Do not commit if the user has explicitly asked to batch commits.

## Task 10: Runtime Contract And Registration Smoke

**Files:**
- Modify: `README.md`
- Modify: `docs/core_foundation.md`
- Create: `modules/notes/docs/REGISTER.md`
- Test: `docker compose run --rm notes_app bin/rails db:prepare`
- Test: `docker compose up -d postgres core notes_app notes_adapter nginx`
- Test: `docker compose exec notes_adapter python -m pytest`
- Test: `bin/ayaya-contract --module-yml modules/notes/module.yml --adapter-url http://127.0.0.1:<temporary-port> --adapter-secret development-notes-adapter-secret`

**Interfaces:**
- Consumes live compose services.
- Produces documented manual registration procedure.

- [ ] **Step 1: Document explicit DB preparation**

Update `README.md` and `modules/notes/docs/README.md`:

```markdown
Prepare the Notes database:

```bash
docker compose run --rm notes_app bin/rails db:prepare
```

Start the platform:

```bash
docker compose up --build
```
```

- [ ] **Step 2: Document manual Core registration**

Create `modules/notes/docs/REGISTER.md`:

```markdown
# Register Notes In Core

1. Start the platform with `docker compose up --build`.
2. Open Core admin.
3. Register adapter URL `http://notes_adapter:8080`.
4. Use adapter secret `development-notes-adapter-secret`.
5. Refresh manifest and status.
6. Enable the module.
7. Open `/m/notes` through NGINX.
```

- [ ] **Step 3: Prepare module database**

Run:

```bash
docker compose run --rm notes_app bin/rails db:prepare
```

Expected: `ayaya_mod_notes` exists and migrations are applied.

- [ ] **Step 4: Start services**

Run:

```bash
docker compose up -d postgres core notes_app notes_adapter nginx
```

Expected: all services running; `core`, `postgres`, and `notes_app` healthy.

- [ ] **Step 5: Run adapter tests inside container**

Run:

```bash
docker compose run --rm notes_adapter python -m pytest
```

Expected: PASS.

- [ ] **Step 6: Validate live adapter endpoints from Docker network**

Run:

```bash
docker compose run --rm notes_adapter python - <<'PY'
import httpx
headers = {"Authorization": "Bearer development-notes-adapter-secret"}
for path in ["/ayaya/manifest", "/ayaya/health/live", "/ayaya/health/ready", "/ayaya/status"]:
    response = httpx.get(f"http://notes_adapter:8080{path}", headers=headers, timeout=5)
    print(path, response.status_code)
    response.raise_for_status()
PY
```

Expected:

```text
/ayaya/manifest 200
/ayaya/health/live 200
/ayaya/health/ready 200
/ayaya/status 200
```

- [ ] **Step 7: Run live contract**

If `notes_adapter` is not published to host, run contract from a container on the compose network or temporarily use `docker compose exec core`:

```bash
docker compose exec core bin/ayaya-contract \
  --module-yml modules/notes/module.yml \
  --adapter-url http://notes_adapter:8080 \
  --adapter-secret development-notes-adapter-secret
```

Expected:

```text
Ayaya contract: PASS
```

- [ ] **Step 8: Commit**

```bash
git add README.md docs/core_foundation.md modules/notes/docs
git commit -m "Document notes module runtime"
```

Do not commit if the user has explicitly asked to batch commits.

## Task 11: NGINX Authenticated UI Smoke Test

**Files:**
- Create: `test/system/notes_module_smoke_test.rb` or document manual smoke in `modules/notes/docs/README.md` if browser automation across compose is unstable.
- Modify: `db/seeds.rb` only if a development admin/user seed is needed for repeatable smoke.

**Interfaces:**
- Consumes Core session authentication.
- Consumes Core module registry entry for `notes`.
- Produces evidence that `/m/notes` works through NGINX and fails without trusted headers.

- [ ] **Step 1: Write smoke test plan before automation**

Document expected smoke flow in `modules/notes/docs/README.md`:

```markdown
## Smoke Test

1. Sign in to Core through `http://localhost:8081`.
2. Ensure `notes` is registered, healthy, enabled, and available to authenticated users.
3. Open `http://localhost:8081/m/notes`.
4. Create a note.
5. Confirm the note appears in the list.
6. Confirm direct internal app access without `X-Ayaya-*` headers returns `401`.
```

- [ ] **Step 2: Add automated system test if feasible**

Create `test/system/notes_module_smoke_test.rb`:

```ruby
require "application_system_test_case"

class NotesModuleSmokeTest < ApplicationSystemTestCase
  test "authenticated user opens notes module link" do
    user = User.create!(email: "user@example.test", password: "password123", role: "user")
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
      manifest_snapshot: {
        "presentation" => { "description" => "Personal notes" },
        "routes" => { "ui_base_path" => "/m/notes" }
      },
      status_snapshot: {}
    )

    visit new_user_session_path
    fill_in "Email", with: user.email
    fill_in "Password", with: "password123"
    click_button "Log in"

    assert_link "Notes", href: "/m/notes"
  end
end
```

This test verifies Core navigation. Full cross-container NGINX UI smoke may remain a documented manual check until the module is available in the same runtime during CI.

- [ ] **Step 3: Test direct app rejection**

Run inside compose:

```bash
docker compose exec nginx wget -S -O - http://notes_app:3000/m/notes
```

Expected: `401 Unauthorized`.

- [ ] **Step 4: Test NGINX route after manual Core registration**

Run from host after signing in in a browser, or use browser automation if session setup is available:

```bash
curl -i http://127.0.0.1:8081/m/notes
```

Expected before login: redirect to Core login or unauthorized according to Core auth flow.

Expected after login and enabled module: `200 OK` with Notes page.

- [ ] **Step 5: Run Core system tests**

Run:

```bash
bin/rails db:test:prepare test:system
```

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add test/system modules/notes/docs
git commit -m "Add notes module smoke coverage"
```

Do not commit if the user has explicitly asked to batch commits.

## Task 12: Final Verification

**Files:**
- Modify: graphify output via `graphify update .`
- No product files should change during this task except documentation corrections found by verification.

**Interfaces:**
- Consumes all prior tasks.
- Produces final confidence that the reference module slice satisfies the design.

- [ ] **Step 1: Run root Core tests**

Run:

```bash
bin/rails test
```

Expected: PASS.

- [ ] **Step 2: Run root system tests**

Run:

```bash
bin/rails db:test:prepare test:system
```

Expected: PASS.

- [ ] **Step 3: Run root lint**

Run:

```bash
RUBOCOP_CACHE_ROOT=tmp/rubocop_cache bin/rubocop
```

Expected: no offenses.

- [ ] **Step 4: Run notes app tests**

Run:

```bash
cd modules/notes/app
bin/rails test
```

Expected: PASS.

- [ ] **Step 5: Run notes adapter tests**

Run:

```bash
cd modules/notes/adapter
python -m pytest
```

Expected: PASS.

- [ ] **Step 6: Validate compose**

Run:

```bash
docker compose config
```

Expected: valid config.

- [ ] **Step 7: Build runtime**

Run:

```bash
docker compose build core notes_app notes_adapter
```

Expected: all images build.

- [ ] **Step 8: Validate NGINX config**

Run:

```bash
docker run --rm -v "$PWD/deploy/nginx/ayaya.example.conf:/etc/nginx/nginx.conf:ro" nginx:1.27-alpine nginx -t
```

Expected: syntax is ok, test is successful.

- [ ] **Step 9: Prepare notes database explicitly**

Run:

```bash
docker compose run --rm notes_app bin/rails db:prepare
```

Expected: migrations complete without automatic startup migrations.

- [ ] **Step 10: Start runtime**

Run:

```bash
docker compose up -d postgres core notes_app notes_adapter nginx
docker compose ps
```

Expected: services are running; healthchecks pass where configured.

- [ ] **Step 11: Run live contract**

Run:

```bash
docker compose exec core bin/ayaya-contract \
  --module-yml modules/notes/module.yml \
  --adapter-url http://notes_adapter:8080 \
  --adapter-secret development-notes-adapter-secret
```

Expected:

```text
Ayaya contract: PASS
```

- [ ] **Step 12: Verify direct module app rejection**

Run:

```bash
docker compose exec nginx wget -S -O - http://notes_app:3000/m/notes
```

Expected: `401 Unauthorized`.

- [ ] **Step 13: Update graph**

Run:

```bash
graphify update .
```

Expected: graph updates without blocking errors.

- [ ] **Step 14: Final status**

Run:

```bash
git status --short
```

Expected: changes are limited to intentional module, compose, docs, tests, and graphify outputs.

## Self-Review

- Spec coverage: Covered bundle structure, Rails app, FastAPI adapter, manifest truth, trusted headers, local users, CRUD, internal status, separate database, compose, NGINX, manual registration, contract tests, smoke tests, and final verification.
- Scope check: The plan excludes tags, search, markdown, sharing, attachments, background jobs, public notes API, auto-registration, dynamic NGINX generation, and module-to-module communication.
- TDD check: Domain logic, identity logic, internal status, adapter endpoints, and contract checks start with failing tests. Rails/FastAPI scaffolding and Dockerfiles are generated/configuration work and are verified with build/config/test commands.
- Type/name consistency: `notes_app`, `notes_adapter`, `ayaya_mod_notes`, `NOTES_ADAPTER_SECRET`, `NOTES_INTERNAL_STATUS_SECRET`, `NOTES_MODULE_YML`, and `/internal/ayaya/status` are used consistently.
- Known risk: Full cross-container browser automation through NGINX may require extra CI wiring. The plan includes a manual/runtime smoke path and keeps Core system smoke separate.

Plan complete and saved to `docs/superpowers/plans/2026-08-01-reference-notes-module.md`.

Two execution options:

**1. Subagent-Driven (recommended)** - dispatch a fresh subagent per task, review between tasks, fast iteration.

**2. Inline Execution** - execute tasks in this session using executing-plans, batch execution with checkpoints.

Which approach?
