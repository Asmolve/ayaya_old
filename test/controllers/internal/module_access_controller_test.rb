require "test_helper"
require "openssl"

class Internal::ModuleAccessControllerTest < ActionDispatch::IntegrationTest
  TELEGRAM_TRUSTED_IDENTITY_SECRET = "telegram-test-trusted-identity-secret"

  setup do
    @previous_telegram_trusted_identity_secret = ENV["TELEGRAM_TRUSTED_IDENTITY_SECRET"]
    ENV["TELEGRAM_TRUSTED_IDENTITY_SECRET"] = TELEGRAM_TRUSTED_IDENTITY_SECRET
  end

  teardown do
    restore_trusted_identity_secret(@previous_telegram_trusted_identity_secret)
  end

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

  test "blocks unregistered module" do
    user = User.create!(email: "user@example.test", password: "password123", role: "user")
    sign_in user

    get "/internal/auth/module_access", headers: { "X-Original-URI" => "/m/unknown" }

    assert_response :forbidden
  end

  test "authorizes only the exact registered Telegram route namespace" do
    user = User.create!(email: "telegram-user@example.test", password: "password123", role: "user")
    sign_in user
    RegisteredModule.create!(
      module_key: "telegram",
      name: "Telegram Dialog Organizer",
      version: "0.1.0",
      adapter_url: "http://telegram_adapter:8080",
      adapter_secret_digest: "digest",
      adapter_protocol_version: "1.0",
      admin_state: "enabled",
      runtime_status: "healthy",
      access_policy_mode: "authenticated",
      manifest_snapshot: {},
      status_snapshot: {}
    )

    [ "/m/telegram", "/m/telegram/", "/m/telegram/imports" ].each do |path|
      get "/internal/auth/module_access", headers: { "X-Original-URI" => path }
      assert_response :no_content, path
      assert_equal "telegram", response.headers["X-Ayaya-Module-Key"], path
    end

    [ "/m/telegramx", "/m/telegram-notes", "/m/telegram.extra" ].each do |path|
      get "/internal/auth/module_access", headers: { "X-Original-URI" => path }
      assert_response :forbidden, path
    end
  end

  test "signs the Telegram identity headers with the configured trusted identity secret" do
    user = User.create!(email: "signed-telegram-user@example.test", password: "password123", role: "user")
    sign_in user
    RegisteredModule.create!(
      module_key: "telegram",
      name: "Telegram Dialog Organizer",
      version: "0.1.0",
      adapter_url: "http://telegram_adapter:8080",
      adapter_secret_digest: "digest",
      adapter_protocol_version: "1.0",
      admin_state: "enabled",
      runtime_status: "healthy",
      access_policy_mode: "authenticated",
      manifest_snapshot: {},
      status_snapshot: {}
    )

    get "/internal/auth/module_access", headers: { "X-Original-URI" => "/m/telegram/" }

    assert_response :no_content
    signed_fields = %w[
      X-Ayaya-User-Id
      X-Ayaya-Module-Key
      X-Ayaya-User-Email
      X-Ayaya-User-Display-Name
      X-Ayaya-User-Role
      X-Ayaya-Request-Id
    ]
    expected = OpenSSL::HMAC.hexdigest("SHA256", TELEGRAM_TRUSTED_IDENTITY_SECRET, signed_fields.map { |field| response.headers[field].to_s }.join("\n"))

    assert_equal expected, response.headers["X-Ayaya-Identity-Signature"]
  end

  test "fails closed for Telegram access when the trusted identity secret is absent" do
    user = User.create!(email: "unsigned-telegram-user@example.test", password: "password123", role: "user")
    sign_in user
    RegisteredModule.create!(
      module_key: "telegram",
      name: "Telegram Dialog Organizer",
      version: "0.1.0",
      adapter_url: "http://telegram_adapter:8080",
      adapter_secret_digest: "digest",
      adapter_protocol_version: "1.0",
      admin_state: "enabled",
      runtime_status: "healthy",
      access_policy_mode: "authenticated",
      manifest_snapshot: {},
      status_snapshot: {}
    )

    with_trusted_identity_secret(nil) do
      get "/internal/auth/module_access", headers: { "X-Original-URI" => "/m/telegram/" }
    end

    assert_response :service_unavailable
    assert_nil response.headers["X-Ayaya-Identity-Signature"]
  end

  private

  def with_trusted_identity_secret(secret)
    previous_secret = ENV["TELEGRAM_TRUSTED_IDENTITY_SECRET"]
    secret.nil? ? ENV.delete("TELEGRAM_TRUSTED_IDENTITY_SECRET") : ENV["TELEGRAM_TRUSTED_IDENTITY_SECRET"] = secret
    yield
  ensure
    restore_trusted_identity_secret(previous_secret)
  end

  def restore_trusted_identity_secret(secret)
    secret.nil? ? ENV.delete("TELEGRAM_TRUSTED_IDENTITY_SECRET") : ENV["TELEGRAM_TRUSTED_IDENTITY_SECRET"] = secret
  end
end
