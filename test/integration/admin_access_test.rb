require "test_helper"
require "nokogiri"
require "set"

class AdminAccessTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  PIC_OBTAINER_MANIFEST = {
    "identity" => { "module_key" => "pic_obtainer", "name" => "Pic Obtainer", "version" => "0.1.0" },
    "protocol" => { "adapter_protocol_version" => "1.0", "capabilities" => [ "manifest.v1", "health.v1", "status.v1" ] },
    "routes" => { "ui_base_path" => "/m/pic_obtainer", "api_base_path" => "/m/pic_obtainer/api" },
    "access" => { "default_policy" => "authenticated" }
  }.freeze

  PicObtainerRegistrationClient = Struct.new(:manifest_response) do
    def manifest = manifest_response
  end

  PLANNING_MANIFEST = {
    "identity" => { "module_key" => "planning", "name" => "Planning", "version" => "0.1.0" },
    "protocol" => { "adapter_protocol_version" => "1.0", "capabilities" => [ "manifest.v1", "health.v1", "status.v1" ] },
    "routes" => { "ui_base_path" => "/m/planning", "api_base_path" => "/m/planning/api" },
    "access" => { "default_policy" => "authenticated" }
  }.freeze

  TELEGRAM_MANIFEST = {
    "identity" => { "module_key" => "telegram", "name" => "Telegram Dialog Organizer", "version" => "0.1.0" },
    "protocol" => { "adapter_protocol_version" => "1.0", "capabilities" => [ "manifest.v1", "health.v1", "status.v1" ] },
    "routes" => { "ui_base_path" => "/m/telegram", "api_base_path" => "/m/telegram/api" },
    "access" => { "default_policy" => "authenticated" }
  }.freeze

  test "signed-in non-admin cannot access ActiveAdmin" do
    user = User.create!(email: "user@example.test", password: "password123", role: "user")
    sign_in user

    get admin_root_path

    assert_response :not_found
  end

  test "inactive user cannot establish a Devise session" do
    user = User.create!(email: "inactive@example.test", password: "password123", role: "user", active: false)

    post user_session_path, params: { user: { email: user.email, password: "password123" } }

    assert_redirected_to new_user_session_path
    get admin_root_path
    assert_redirected_to new_user_session_path
  end

  test "signed-in admin can access ActiveAdmin dashboard" do
    admin = User.create!(email: "admin@example.test", password: "password123", role: "admin")
    sign_in admin

    get admin_root_path

    assert_response :success
  end

  test "admin dashboard explains empty module registry" do
    RegisteredModule.destroy_all
    admin = User.create!(email: "empty-dashboard-admin@example.test", password: "password123", role: "admin")
    sign_in admin

    get admin_root_path

    assert_response :success
    assert_includes response.body, "No modules registered"
    assert_includes response.body, "Register the local Notes adapter"
    assert_includes response.body, "Register Pic Obtainer"
    assert_includes response.body, "Register Planning"
    assert_includes response.body, "Register Telegram"
  end

  test "dashboard renders standard POST forms for local module registration" do
    RegisteredModule.destroy_all
    admin = User.create!(email: "registration-form-admin@example.test", password: "password123", role: "admin")
    sign_in admin

    get admin_root_path

    assert_select "form[action='#{admin_dashboard_register_reference_notes_path}'][method='post']" do
      assert_select "button[type='submit']", text: "Register the local Notes adapter"
    end
    assert_select "form[action='#{admin_dashboard_register_pic_obtainer_path}'][method='post']" do
      assert_select "button[type='submit']", text: "Register Pic Obtainer"
    end
    assert_select "form[action='#{admin_dashboard_register_planning_path}'][method='post']" do
      assert_select "button[type='submit']", text: "Register Planning"
    end
    assert_select "form[action='#{admin_dashboard_register_telegram_path}'][method='post']" do
      assert_select "button[type='submit']", text: "Register Telegram"
    end
  end

  test "admin can register Planning from the dashboard" do
    admin = User.create!(email: "planning-admin@example.test", password: "password123", role: "admin")
    sign_in admin

    with_planning_configuration do
      stub_registration_client(PLANNING_MANIFEST) do
        post admin_dashboard_register_planning_path
      end
    end

    registered_module = RegisteredModule.find_by!(module_key: "planning")
    assert_redirected_to admin_registered_module_path(registered_module)
    assert_equal "registered", registered_module.admin_state
  end

  test "admin can register Telegram from the dashboard" do
    admin = User.create!(email: "telegram-admin@example.test", password: "password123", role: "admin")
    sign_in admin

    with_telegram_configuration do
      stub_registration_client(TELEGRAM_MANIFEST) do
        post admin_dashboard_register_telegram_path
      end
    end

    registered_module = RegisteredModule.find_by!(module_key: "telegram")
    assert_redirected_to admin_registered_module_path(registered_module)
    assert_equal "registered", registered_module.admin_state
  end

  test "admin can register Pic Obtainer from the dashboard" do
    admin = User.create!(email: "pic-admin@example.test", password: "password123", role: "admin")
    sign_in admin

    with_pic_obtainer_configuration do
      stub_registration_client(PIC_OBTAINER_MANIFEST) do
        post admin_dashboard_register_pic_obtainer_path
      end
    end

    registered_module = RegisteredModule.find_by!(module_key: "pic_obtainer")
    assert_redirected_to admin_registered_module_path(registered_module)
    assert_equal "registered", registered_module.admin_state
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

  test "registered module admin explains availability blocker" do
    admin = User.create!(email: "availability-admin@example.test", password: "password123", role: "admin")
    mod = RegisteredModule.create!(
      module_key: "blocked_notes",
      name: "Blocked Notes",
      version: "0.1.0",
      adapter_url: "http://notes_adapter:8080",
      adapter_secret_digest: "digest",
      adapter_protocol_version: "1.0",
      admin_state: "enabled",
      runtime_status: "unreachable",
      access_policy_mode: "authenticated",
      manifest_snapshot: {},
      status_snapshot: {},
    )
    sign_in admin

    get admin_registered_module_path(mod)

    assert_response :success
    assert_includes response.body, "needs attention"
    assert_includes response.body, "Module runtime is unreachable. Refresh status or fix the module service."
  end

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

  test "signed-in admin can follow ActiveAdmin GET links" do
    admin = User.create!(email: "link-admin@example.test", password: "password123", role: "admin")
    RegisteredModule.create!(
      module_key: "link_check_notes",
      name: "Link Check Notes",
      version: "0.0.1",
      adapter_url: "http://notes_adapter:8080",
      adapter_secret_digest: "digest",
      adapter_protocol_version: "v1",
      admin_state: "enabled",
      runtime_status: "healthy",
      access_policy_mode: "authenticated",
      manifest_snapshot: {},
      status_snapshot: {},
    )
    sign_in admin

    failures = []
    visited_paths = Set.new
    pending_paths = [ admin_root_path ]

    until pending_paths.empty?
      path = pending_paths.shift
      next if visited_paths.include?(path)

      visited_paths << path
      get path
      failures << [ path, response.status ] unless response.status.between?(200, 399)

      next unless response.successful? && response.media_type == "text/html"

      admin_get_links(response.body).each do |href|
        next if visited_paths.include?(href)

        pending_paths << href
      end
    end

    assert_empty failures, failures.map { |path, status| "#{status} #{path}" }.join("\n")
  end

  test "admins cannot delete users through ActiveAdmin" do
    admin = User.create!(email: "admin@example.test", password: "password123", role: "admin")
    target = User.create!(email: "target@example.test", password: "password123", role: "user")
    sign_in admin

    delete admin_user_path(target)

    assert_response :not_found
    assert User.exists?(target.id)
  end

  test "ActiveAdmin does not configure destructive batch actions" do
    ActiveAdmin.application.load!

    resource = ActiveAdmin.application.namespaces[:admin].resources[User]

    assert_empty resource.batch_actions
  end

  private

    def with_pic_obtainer_configuration
      old_adapter_url = ENV["PIC_OBTAINER_ADAPTER_URL"]
      old_adapter_secret = ENV["PIC_OBTAINER_AYAYA_ADAPTER_SECRET"]
      ENV["PIC_OBTAINER_ADAPTER_URL"] = "http://pic_obtainer_api:8000"
      ENV["PIC_OBTAINER_AYAYA_ADAPTER_SECRET"] = "secret"
      yield
    ensure
      restore_env("PIC_OBTAINER_ADAPTER_URL", old_adapter_url)
      restore_env("PIC_OBTAINER_AYAYA_ADAPTER_SECRET", old_adapter_secret)
    end

    def with_planning_configuration
      old_adapter_url = ENV["PLANNING_ADAPTER_URL"]
      old_adapter_secret = ENV["PLANNING_ADAPTER_SECRET"]
      ENV["PLANNING_ADAPTER_URL"] = "http://planning_adapter:8080"
      ENV["PLANNING_ADAPTER_SECRET"] = "planning-secret"
      yield
    ensure
      restore_env("PLANNING_ADAPTER_URL", old_adapter_url)
      restore_env("PLANNING_ADAPTER_SECRET", old_adapter_secret)
    end

    def with_telegram_configuration
      old_adapter_url = ENV["TELEGRAM_ADAPTER_URL"]
      old_adapter_secret = ENV["TELEGRAM_ADAPTER_SECRET"]
      ENV["TELEGRAM_ADAPTER_URL"] = "http://telegram_adapter:8080"
      ENV["TELEGRAM_ADAPTER_SECRET"] = "telegram-secret"
      yield
    ensure
      restore_env("TELEGRAM_ADAPTER_URL", old_adapter_url)
      restore_env("TELEGRAM_ADAPTER_SECRET", old_adapter_secret)
    end

    def stub_registration_client(manifest)
      original_new = AdapterProtocol::Client.method(:new)
      client = PicObtainerRegistrationClient.new(manifest)
      AdapterProtocol::Client.define_singleton_method(:new) { |**| client }
      yield
    ensure
      AdapterProtocol::Client.define_singleton_method(:new, original_new)
    end

    def create_registered_module(module_key:)
      RegisteredModule.create!(
        module_key:,
        name: "Pic Obtainer",
        version: "0.1.0",
        adapter_url: "http://pic_obtainer_api:8000",
        adapter_secret_digest: "digest",
        adapter_protocol_version: "1.0",
        admin_state: "registered",
        runtime_status: "unknown",
        access_policy_mode: "authenticated",
        manifest_snapshot: {},
        status_snapshot: {}
      )
    end

    def restore_env(key, value)
      value.nil? ? ENV.delete(key) : ENV[key] = value
    end

    def admin_get_links(html)
      Nokogiri::HTML5(html).css("a[href]").filter_map do |anchor|
        next if anchor["data-method"].present? || anchor["data-turbo-method"].present?

        uri = URI.parse(anchor["href"])
        next if uri.scheme.present? && !%w[http https].include?(uri.scheme)
        next if uri.host.present? && uri.host != "www.example.com"
        next unless uri.path.start_with?("/admin")

        [ uri.path, uri.query.presence ].compact.join("?")
      rescue URI::InvalidURIError
        nil
      end.uniq
    end
end
