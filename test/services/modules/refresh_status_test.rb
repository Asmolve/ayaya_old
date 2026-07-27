require "test_helper"

class Modules::RefreshStatusTest < ActiveSupport::TestCase
  FakeClient = Struct.new(:status_response, :error) do
    def status
      raise error if error
      status_response
    end
  end

  def registered_module
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
      status_snapshot: { "runtime_status" => "healthy" }
    )
  end

  test "rejects a non-object status response and fails closed" do
    mod = registered_module
    result = Modules::RefreshStatus.call(registered_module: mod, adapter_secret: "secret", client: FakeClient.new([], nil))

    assert_not result.success?
    assert_equal "incompatible", mod.reload.runtime_status
    assert_equal "adapter status response must be a JSON object", mod.status_snapshot["error"]
  end

  test "marks transport failures unreachable" do
    mod = registered_module
    result = Modules::RefreshStatus.call(registered_module: mod, adapter_secret: "secret", client: FakeClient.new(nil, AdapterProtocol::Client::Unavailable.new("timeout")))

    assert_not result.success?
    assert_equal "unreachable", mod.reload.runtime_status
    assert_equal "timeout", mod.status_snapshot["error"]
  end

  test "marks unauthorized responses incompatible" do
    mod = registered_module
    result = Modules::RefreshStatus.call(registered_module: mod, adapter_secret: "secret", client: FakeClient.new(nil, AdapterProtocol::Client::Unauthorized.new("denied")))

    assert_not result.success?
    assert_equal "incompatible", mod.reload.runtime_status
    assert_equal "denied", mod.status_snapshot["error"]
  end

  test "marks invalid responses incompatible" do
    mod = registered_module
    result = Modules::RefreshStatus.call(registered_module: mod, adapter_secret: "secret", client: FakeClient.new(nil, AdapterProtocol::Client::InvalidResponse.new("bad json")))

    assert_not result.success?
    assert_equal "incompatible", mod.reload.runtime_status
    assert_equal "bad json", mod.status_snapshot["error"]
  end
end
