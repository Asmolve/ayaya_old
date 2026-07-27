require "test_helper"

class Modules::RefreshManifestTest < ActiveSupport::TestCase
  VALID_MANIFEST = {
    "identity" => { "module_key" => "notes", "name" => "New Notes", "version" => "0.2.0" },
    "protocol" => { "adapter_protocol_version" => "1.0", "capabilities" => ["manifest.v1", "health.v1", "status.v1"] },
    "routes" => { "ui_base_path" => "/m/notes", "api_base_path" => "/m/notes/api" },
    "access" => { "default_policy" => "authenticated" }
  }.freeze

  FakeClient = Struct.new(:manifest_response) do
    def manifest = manifest_response
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
      access_policy_mode: "manual",
      manifest_snapshot: { "original" => true },
      status_snapshot: {}
    )
  end

  test "rejects a manifest for a different registered module without replacing core data" do
    mod = registered_module
    original_snapshot = mod.manifest_snapshot

    manifest = VALID_MANIFEST.deep_dup
    manifest["identity"]["module_key"] = "calendar"
    manifest["routes"]["ui_base_path"] = "/m/calendar"
    manifest["routes"]["api_base_path"] = "/m/calendar/api"
    result = Modules::RefreshManifest.call(registered_module: mod, adapter_secret: "secret", client: FakeClient.new(manifest))

    assert_not result.success?
    assert_includes result.errors.first, "does not match registered module"
    mod.reload
    assert_equal "incompatible", mod.runtime_status
    assert_equal original_snapshot, mod.manifest_snapshot
    assert_equal "manual", mod.access_policy_mode
    assert_equal "Notes", mod.name
    assert_equal "0.1.0", mod.version
  end

  test "stores a compatible manifest" do
    mod = registered_module

    result = Modules::RefreshManifest.call(registered_module: mod, adapter_secret: "secret", client: FakeClient.new(VALID_MANIFEST))

    assert result.success?
    assert_equal VALID_MANIFEST, mod.reload.manifest_snapshot
    assert_equal "New Notes", mod.name
  end
end
