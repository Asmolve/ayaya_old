require "test_helper"

class AyayaContract::RunnerTest < ActiveSupport::TestCase
  VALID_MANIFEST = {
    "identity" => { "module_key" => "notes", "name" => "Notes", "version" => "0.1.0" },
    "protocol" => { "adapter_protocol_version" => "1.0", "capabilities" => ["manifest.v1", "health.v1", "status.v1"] },
    "routes" => { "ui_base_path" => "/m/notes", "api_base_path" => "/m/notes/api" },
    "access" => { "default_policy" => "authenticated" }
  }.freeze

  test "passes when package and runtime critical fields match" do
    runner = AyayaContract::Runner.new(package_manifest: VALID_MANIFEST, runtime_manifest: VALID_MANIFEST)

    assert runner.call.success?
  end

  test "fails when runtime module key differs" do
    runtime = VALID_MANIFEST.deep_dup
    runtime["identity"]["module_key"] = "other"
    runner = AyayaContract::Runner.new(package_manifest: VALID_MANIFEST, runtime_manifest: runtime)

    result = runner.call

    assert_not result.success?
    assert_includes result.errors, "critical field mismatch: identity.module_key"
  end
end
