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

  test "pic obtainer services remain internal and migration gated" do
    compose = YAML.safe_load_file("compose.yml", aliases: true)
    services = compose.fetch("services")

    assert %w[pic_obtainer_api pic_obtainer_migrate pic_obtainer_postgres pic_obtainer_worker].all? { |name| services.key?(name) }
    assert_nil services.dig("pic_obtainer_api", "ports")
    assert_nil services.dig("pic_obtainer_worker", "ports")
    assert_equal "${PIC_OBTAINER_AYAYA_ADAPTER_SECRET:?Set PIC_OBTAINER_AYAYA_ADAPTER_SECRET in .env}", services.dig("core", "environment", "PIC_OBTAINER_AYAYA_ADAPTER_SECRET")
    refute_includes services.fetch("core").fetch("environment").keys, "PIC_OBTAINER_RULE34_API_KEY"
    assert_equal "service_healthy", services.dig("pic_obtainer_migrate", "depends_on", "pic_obtainer_postgres", "condition")
    assert_equal "service_completed_successfully", services.dig("pic_obtainer_api", "depends_on", "pic_obtainer_migrate", "condition")
    assert_equal "service_completed_successfully", services.dig("pic_obtainer_worker", "depends_on", "pic_obtainer_migrate", "condition")
    assert_equal "ayaya_mod_pic_obtainer", services.dig("pic_obtainer_postgres", "environment", "POSTGRES_DB")
    refute_includes services.fetch("pic_obtainer_api").fetch("environment").keys, "PIC_OBTAINER_RULE34_API_KEY"
  end

  test "publishes the platform edge on the public development port" do
    compose = YAML.safe_load_file("compose.yml", aliases: true)
    services = compose.fetch("services")

    assert_equal [ "${CORE_HOST_PORT:?Set CORE_HOST_PORT in .env}:3000" ], services.dig("core", "ports")
    assert_equal [ "${NGINX_HOST_PORT:?Set NGINX_HOST_PORT in .env}:80" ], services.dig("nginx", "ports")
  end

  test "preserves the public host and port through nginx" do
    nginx = File.read("deploy/nginx/ayaya.example.conf")

    assert_equal 5, nginx.scan("proxy_set_header Host $http_host;").length
    assert_includes nginx, "proxy_set_header X-Forwarded-Host $http_host;"
    assert_not_includes nginx, "proxy_set_header X-Forwarded-Port $server_port;"
  end

  test "routes Pic Obtainer through Core auth and rebuilds trusted headers" do
    nginx = File.read("deploy/nginx/ayaya.example.conf")

    assert_includes nginx, "location /m/pic_obtainer/"
    assert_includes nginx, "proxy_pass http://$pic_obtainer_api_upstream:8000/;"
    assert_equal 3, nginx.scan("auth_request /internal/auth/module_access;").length
    assert_includes nginx, "proxy_set_header X-Ayaya-Module-Key $ayaya_module_key;"
    assert_includes nginx, "proxy_pass_request_headers off;"
  end

  test "routes Planning through Core auth and rebuilds trusted headers" do
    nginx = File.read("deploy/nginx/ayaya.example.conf")

    assert_includes nginx, "location /m/planning"
    assert_includes nginx, "proxy_pass http://$planning_app_upstream:3000;"
    assert_includes nginx, "proxy_set_header X-Ayaya-Module-Key $ayaya_module_key;"
    assert_includes nginx, "proxy_pass_request_headers off;"
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
      PIC_OBTAINER_IMAGE PIC_OBTAINER_POSTGRES_PASSWORD PIC_OBTAINER_MEDIA_HOST_PATH
      PIC_OBTAINER_DATABASE_URL
      PIC_OBTAINER_IMPORT_HOST_PATH PIC_OBTAINER_AYAYA_ADAPTER_SECRET
      PIC_OBTAINER_RULE34_USER_ID PIC_OBTAINER_RULE34_API_KEY
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
