require "test_helper"

class PicObtainerModuleTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  def registered_module
    RegisteredModule.create!(
      module_key: "pic_obtainer",
      name: "Pic Obtainer",
      version: "0.1.0",
      adapter_url: "http://pic_obtainer_api:8000",
      adapter_secret_digest: Digest::SHA256.hexdigest("secret"),
      adapter_protocol_version: "1.0",
      admin_state: "enabled",
      runtime_status: "healthy",
      access_policy_mode: "admin_only",
      manifest_snapshot: {},
      status_snapshot: {}
    )
  end

  test "admin can pass Core module auth for Pic Obtainer" do
    registered_module
    admin = User.create!(email: "pic-admin@example.test", password: "password123", role: "admin")
    sign_in admin

    get "/internal/auth/module_access", headers: { "X-Original-URI" => "/m/pic_obtainer/" }

    assert_response :no_content
    assert_equal "pic_obtainer", response.headers["X-Ayaya-Module-Key"]
    assert_equal admin.id.to_s, response.headers["X-Ayaya-User-Id"]
  end

  test "regular user is rejected by the Pic Obtainer admin-only policy" do
    registered_module
    user = User.create!(email: "pic-user@example.test", password: "password123", role: "user")
    sign_in user

    get "/internal/auth/module_access", headers: { "X-Original-URI" => "/m/pic_obtainer/" }

    assert_response :forbidden
  end

  test "Core selects the Pic Obtainer adapter secret for refreshes and fails closed" do
    mod = registered_module
    ENV["PIC_OBTAINER_AYAYA_ADAPTER_SECRET"] = "pic-secret"

    assert_equal "pic-secret", Modules::AdapterSecret.for(mod)

    ENV.delete("PIC_OBTAINER_AYAYA_ADAPTER_SECRET")
    assert_nil Modules::AdapterSecret.for(mod)
  ensure
    ENV.delete("PIC_OBTAINER_AYAYA_ADAPTER_SECRET")
  end

  test "disabled or unhealthy Pic Obtainer is unavailable at the auth boundary" do
    admin = User.create!(email: "pic-boundary-admin@example.test", password: "password123", role: "admin")
    mod = registered_module
    sign_in admin

    mod.update!(admin_state: "disabled")
    get "/internal/auth/module_access", headers: { "X-Original-URI" => "/m/pic_obtainer/" }
    assert_response :forbidden

    mod.update!(admin_state: "enabled", runtime_status: "unhealthy")
    get "/internal/auth/module_access", headers: { "X-Original-URI" => "/m/pic_obtainer/" }
    assert_response :service_unavailable
  end
end
