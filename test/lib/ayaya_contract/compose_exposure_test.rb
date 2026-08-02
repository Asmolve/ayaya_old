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

  test "publishes the platform edge on the public development port" do
    compose = YAML.safe_load_file("compose.yml", aliases: true)
    services = compose.fetch("services")

    assert_equal ["3001:3000"], services.dig("core", "ports")
    assert_equal ["3000:80"], services.dig("nginx", "ports")
  end

  test "preserves the public host and port through nginx" do
    nginx = File.read("deploy/nginx/ayaya.example.conf")

    assert_equal 3, nginx.scan("proxy_set_header Host $http_host;").length
    assert_includes nginx, "proxy_set_header X-Forwarded-Host $http_host;"
    assert_not_includes nginx, "proxy_set_header X-Forwarded-Port $server_port;"
  end
end
