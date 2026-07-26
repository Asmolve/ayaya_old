require "test_helper"

class AdapterProtocol::ManifestValidatorTest < ActiveSupport::TestCase
  VALID_MANIFEST = {
    "identity" => {
      "module_key" => "notes",
      "name" => "Notes",
      "version" => "0.1.0"
    },
    "protocol" => {
      "adapter_protocol_version" => "1.0",
      "capabilities" => ["manifest.v1", "health.v1", "status.v1"]
    },
    "routes" => {
      "ui_base_path" => "/m/notes",
      "api_base_path" => "/m/notes/api"
    },
    "access" => {
      "default_policy" => "authenticated"
    }
  }.freeze

  test "accepts valid manifest" do
    result = AdapterProtocol::ManifestValidator.call(VALID_MANIFEST)

    assert result.valid?
    assert_empty result.errors
  end

  test "rejects invalid module key" do
    manifest = VALID_MANIFEST.deep_dup
    manifest["identity"]["module_key"] = "notes-app"

    result = AdapterProtocol::ManifestValidator.call(manifest)

    assert_not result.valid?
    assert_includes result.errors, "identity.module_key must be snake_case"
  end

  test "requires v1 capabilities" do
    manifest = VALID_MANIFEST.deep_dup
    manifest["protocol"]["capabilities"] = ["manifest.v1"]

    result = AdapterProtocol::ManifestValidator.call(manifest)

    assert_not result.valid?
    assert_includes result.errors, "protocol.capabilities must include health.v1"
    assert_includes result.errors, "protocol.capabilities must include status.v1"
  end

  test "requires routes under module namespace" do
    manifest = VALID_MANIFEST.deep_dup
    manifest["routes"]["ui_base_path"] = "/notes"

    result = AdapterProtocol::ManifestValidator.call(manifest)

    assert_not result.valid?
    assert_includes result.errors, "routes.ui_base_path must equal /m/notes"
  end
end
