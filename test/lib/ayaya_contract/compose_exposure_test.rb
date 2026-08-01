require "test_helper"
require "yaml"

class AyayaContract::ComposeExposureTest < ActiveSupport::TestCase
  test "notes app and adapter do not publish host ports" do
    compose = YAML.safe_load_file("compose.yml", aliases: true)
    services = compose.fetch("services")

    assert services.key?("notes_app")
    assert services.key?("notes_adapter")
    assert_nil services.dig("notes_app", "ports")
    assert_nil services.dig("notes_adapter", "ports")
  end
end
