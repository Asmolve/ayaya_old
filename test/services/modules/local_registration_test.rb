require "test_helper"

class Modules::LocalRegistrationTest < ActiveSupport::TestCase
  VALID_MANIFEST = {
    "identity" => { "module_key" => "pic_obtainer", "name" => "Pic Obtainer", "version" => "0.1.0" },
    "protocol" => { "adapter_protocol_version" => "1.0", "capabilities" => [ "manifest.v1", "health.v1", "status.v1" ] },
    "routes" => { "ui_base_path" => "/m/pic_obtainer", "api_base_path" => "/m/pic_obtainer/api" },
    "access" => { "default_policy" => "authenticated" }
  }.freeze

  FakeClient = Struct.new(:manifest_response) do
    def manifest = manifest_response
  end

  FailingClient = Struct.new(:error) do
    def manifest
      raise error
    end
  end

  setup do
    @adapter_url = ENV["PIC_OBTAINER_ADAPTER_URL"]
    @adapter_secret = ENV["PIC_OBTAINER_AYAYA_ADAPTER_SECRET"]
  end

  teardown do
    restore_env("PIC_OBTAINER_ADAPTER_URL", @adapter_url)
    restore_env("PIC_OBTAINER_AYAYA_ADAPTER_SECRET", @adapter_secret)
  end

  test "resolves Pic Obtainer local registration configuration" do
    config = Modules::LocalRegistration.configuration("pic_obtainer")

    assert_equal "pic_obtainer", config.module_key
    assert_equal "Pic Obtainer", config.display_name
    assert_equal "PIC_OBTAINER_ADAPTER_URL", config.adapter_url_env
    assert_equal "PIC_OBTAINER_AYAYA_ADAPTER_SECRET", config.adapter_secret_env
    assert_predicate config, :frozen?
    assert_raises(FrozenError) { config.module_key << "_changed" }
    assert_raises(FrozenError) { config.display_name << " changed" }
    assert_raises(FrozenError) { config.adapter_url_env << "_CHANGED" }
    assert_raises(FrozenError) { config.adapter_secret_env << "_CHANGED" }
  end

  test "registers Pic Obtainer with server-side credentials" do
    ENV["PIC_OBTAINER_ADAPTER_URL"] = "http://pic_obtainer_api:8000"
    ENV["PIC_OBTAINER_AYAYA_ADAPTER_SECRET"] = "secret"

    result = Modules::LocalRegistration.call("pic_obtainer", client: FakeClient.new(VALID_MANIFEST))

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

  test "does not expose credentials in adapter errors" do
    ENV["PIC_OBTAINER_ADAPTER_URL"] = "http://pic_obtainer_api:8000"
    ENV["PIC_OBTAINER_AYAYA_ADAPTER_SECRET"] = "secret"

    result = Modules::LocalRegistration.call(
      "pic_obtainer",
      client: FailingClient.new(AdapterProtocol::Client::Unavailable.new("adapter rejected secret"))
    )

    assert_not result.success?
    assert_not_includes result.errors.join("; "), "secret"
  end

  test "does not create a duplicate for an already registered module" do
    existing = create_registered_module(module_key: "pic_obtainer")

    result = Modules::LocalRegistration.call("pic_obtainer")

    assert result.success?
    assert_equal existing.id, result.registered_module.id
    assert_equal 1, RegisteredModule.where(module_key: "pic_obtainer").count
  end

  private

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
end
