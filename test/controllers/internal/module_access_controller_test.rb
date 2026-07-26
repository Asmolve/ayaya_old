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
