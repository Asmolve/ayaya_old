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
