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

    assert_equal [ "${CORE_HOST_PORT:?Set CORE_HOST_PORT in .env}:3000" ], services.dig("core", "ports")
    assert_equal [ "${NGINX_HOST_PORT:?Set NGINX_HOST_PORT in .env}:80" ], services.dig("nginx", "ports")
  end

  test "preserves the public host and port through nginx" do
    nginx = File.read("deploy/nginx/ayaya.example.conf")

    assert_equal 3, nginx.scan("proxy_set_header Host $http_host;").length
    assert_includes nginx, "proxy_set_header X-Forwarded-Host $http_host;"
    assert_not_includes nginx, "proxy_set_header X-Forwarded-Port $server_port;"
  end

  test "provides a complete tracked compose environment template" do
    template = File.read(".env.example")

    %w[
      POSTGRES_USER POSTGRES_PASSWORD DATABASE_USERNAME DATABASE_PASSWORD
      CORE_DATABASE_NAME NOTES_DATABASE_NAME
      DATABASE_HOST DATABASE_PORT RAILS_ENV RAILS_LOG_TO_STDOUT
      CORE_ALLOWED_HOSTS NOTES_ALLOWED_HOSTS NOTES_ADAPTER_URL
      NOTES_ADAPTER_SECRET NOTES_INTERNAL_STATUS_SECRET
      NOTES_APP_INTERNAL_STATUS_URL NOTES_MODULE_YML CORE_HOST_PORT NGINX_HOST_PORT
    ].each do |key|
      assert_match(/^#{key}=/, template)
    end

    assert_includes template, "NOTES_ADAPTER_SECRET=replace-with-a-unique-secret"
    assert_includes template, "NOTES_INTERNAL_STATUS_SECRET=replace-with-a-unique-secret"
    assert_includes File.read(".gitignore"), "!/.env.example"
    assert_includes File.read(".dockerignore"), "!/.env.example"
  end

  test "gets compose environment and published ports from env variables" do
    compose = File.read("compose.yml")

    assert_includes compose, "POSTGRES_PASSWORD: ${POSTGRES_PASSWORD:?Set POSTGRES_PASSWORD in .env}"
    assert_includes compose, '"${CORE_HOST_PORT:?Set CORE_HOST_PORT in .env}:3000"'
    assert_not_includes compose, "POSTGRES_PASSWORD: ayaya"
  end

  test "preserves the standalone Notes database credential interface" do
    notes_compose = File.read("modules/notes/compose.yml")

    assert_includes notes_compose, "DATABASE_USERNAME: ${DATABASE_USERNAME:?Set DATABASE_USERNAME in .env}"
    assert_includes notes_compose, "DATABASE_PASSWORD: ${DATABASE_PASSWORD:?Set DATABASE_PASSWORD in .env}"
    assert_includes File.read("modules/notes/docs/README.md"), "docker compose --env-file .env -f modules/notes/compose.yml"
  end
end
