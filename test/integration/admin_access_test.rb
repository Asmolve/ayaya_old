require "test_helper"
require "nokogiri"
require "set"

class AdminAccessTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

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
