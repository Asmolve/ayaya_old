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
    assert_equal "${PLANNING_ADAPTER_URL:?Set PLANNING_ADAPTER_URL in .env}", services.dig("core", "environment", "PLANNING_ADAPTER_URL")
    assert_equal "${PLANNING_ADAPTER_SECRET:?Set PLANNING_ADAPTER_SECRET in .env}", services.dig("core", "environment", "PLANNING_ADAPTER_SECRET")
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

    assert_equal 6, nginx.scan("proxy_set_header Host $http_host;").length
    assert_includes nginx, "proxy_set_header X-Forwarded-Host $http_host;"
    assert_not_includes nginx, "proxy_set_header X-Forwarded-Port $server_port;"
  end

  test "routes Pic Obtainer through Core auth and rebuilds trusted headers" do
    nginx = File.read("deploy/nginx/ayaya.example.conf")

    assert_includes nginx, "location /m/pic_obtainer/"
    assert_includes nginx, "proxy_pass http://$pic_obtainer_api_upstream:8000/;"
    assert_equal 4, nginx.scan("auth_request /internal/auth/module_access;").length
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

  test "wires Telegram Core registration through only the Adapter" do
    compose = YAML.safe_load_file("compose.yml", aliases: true)
    core_environment = compose.fetch("services").fetch("core").fetch("environment")

    assert_equal "${TELEGRAM_ADAPTER_URL:?Set TELEGRAM_ADAPTER_URL in .env}", core_environment["TELEGRAM_ADAPTER_URL"]
    assert_equal "${TELEGRAM_ADAPTER_SECRET:?Set TELEGRAM_ADAPTER_SECRET in .env}", core_environment["TELEGRAM_ADAPTER_SECRET"]
    assert_equal "${TELEGRAM_TRUSTED_IDENTITY_SECRET:?Set TELEGRAM_TRUSTED_IDENTITY_SECRET in .env}", core_environment["TELEGRAM_TRUSTED_IDENTITY_SECRET"]
    assert_equal core_environment.fetch("TELEGRAM_TRUSTED_IDENTITY_SECRET"), compose.fetch("services").dig("telegram_app", "environment", "TELEGRAM_TRUSTED_IDENTITY_SECRET")
    assert_equal %w[TELEGRAM_ADAPTER_SECRET TELEGRAM_ADAPTER_URL TELEGRAM_TRUSTED_IDENTITY_SECRET], core_environment.keys.grep(/\ATELEGRAM_/).sort
  end

  test "keeps Telegram App and Adapter private while separating their secrets" do
    compose = YAML.safe_load_file("compose.yml", aliases: true)
    services = compose.fetch("services")

    assert services.key?("telegram_app")
    assert services.key?("telegram_adapter")
    assert_nil services.dig("telegram_app", "ports")
    assert_nil services.dig("telegram_adapter", "ports")
    assert_equal "${TELEGRAM_INTERNAL_STATUS_SECRET:?Set TELEGRAM_INTERNAL_STATUS_SECRET in .env}", services.dig("telegram_app", "environment", "TELEGRAM_INTERNAL_STATUS_SECRET")
    assert_equal "${TELEGRAM_TRUSTED_IDENTITY_SECRET:?Set TELEGRAM_TRUSTED_IDENTITY_SECRET in .env}", services.dig("telegram_app", "environment", "TELEGRAM_TRUSTED_IDENTITY_SECRET")
    refute_includes services.fetch("telegram_app").fetch("environment").keys, "TELEGRAM_ADAPTER_SECRET"
    assert_equal "${TELEGRAM_ADAPTER_SECRET:?Set TELEGRAM_ADAPTER_SECRET in .env}", services.dig("telegram_adapter", "environment", "TELEGRAM_ADAPTER_SECRET")
    assert_equal "http://telegram_app:3000/internal/ayaya/status", services.dig("telegram_adapter", "environment", "TELEGRAM_APP_INTERNAL_STATUS_URL")
  end

  test "deploys Telegram with explicit production secrets, migration, and health gates" do
    compose = YAML.safe_load_file("compose.yml", aliases: true)
    services = compose.fetch("services")
    app = services.fetch("telegram_app")

    assert_equal "production", app.dig("environment", "RAILS_ENV")
    assert_equal "${TELEGRAM_SECRET_KEY_BASE:?Set TELEGRAM_SECRET_KEY_BASE in .env}", app.dig("environment", "SECRET_KEY_BASE")
    assert_equal "/run/secrets/telegram_envelope_keyring", app.dig("environment", "TELEGRAM_ENVELOPE_KEY_FILE")
    assert_equal "${TELEGRAM_MTPROTO_CLIENT_URL:?Set TELEGRAM_MTPROTO_CLIENT_URL in .env}", app.dig("environment", "TELEGRAM_MTPROTO_CLIENT_URL")
    assert_equal "${TELEGRAM_MTPROTO_CLIENT_TOKEN:?Set TELEGRAM_MTPROTO_CLIENT_TOKEN in .env}", app.dig("environment", "TELEGRAM_MTPROTO_CLIENT_TOKEN")
    assert_equal [ "telegram_envelope_keyring" ], app.fetch("secrets")
    assert_equal [ "CMD-SHELL", "curl -fsS http://localhost:3000/up >/dev/null" ], app.dig("healthcheck", "test")
    assert_equal [ "bin/rails", "db:migrate" ], services.dig("telegram_migrate", "command")
    assert_equal [ "telegram_app_postgres" ], services.dig("telegram_migrate", "networks")
    assert_equal "service_healthy", services.dig("telegram_adapter", "depends_on", "telegram_app", "condition")
    assert_equal({ "file" => "${TELEGRAM_ENVELOPE_KEY_FILE:?Set TELEGRAM_ENVELOPE_KEY_FILE to the keyring secret file}" }, compose.dig("secrets", "telegram_envelope_keyring"))
  end

  test "runs the Telegram worker with the app runtime contract after migrations" do
    compose = YAML.safe_load_file("compose.yml", aliases: true)
    services = compose.fetch("services")
    app = services.fetch("telegram_app")
    worker = services.fetch("telegram_worker")

    assert_equal [ "bin/telegram_worker" ], worker.fetch("command")
    assert_equal "unless-stopped", worker.fetch("restart")
    assert_equal app.fetch("environment"), worker.fetch("environment")
    assert_equal app.fetch("secrets"), worker.fetch("secrets")
    assert_equal [ "telegram_app_postgres", "telegram_app_mtproto" ], worker.fetch("networks")
    assert_nil worker["ports"]
    assert_equal "service_completed_successfully", worker.dig("depends_on", "telegram_migrate", "condition")
  end

  test "provisions the Telegram database role before migrating or starting the app" do
    compose = YAML.safe_load_file("compose.yml", aliases: true)
    services = compose.fetch("services")
    provisioner = services.fetch("telegram_database")

    assert_equal "postgres:16-alpine", provisioner.fetch("image")
    assert_equal "service_healthy", provisioner.dig("depends_on", "postgres", "condition")
    assert_equal [ "telegram_app_postgres" ], provisioner.fetch("networks")
    assert_equal "${TELEGRAM_DATABASE_NAME:?Set TELEGRAM_DATABASE_NAME in .env}", provisioner.dig("environment", "TELEGRAM_DATABASE_NAME")
    assert_equal "${TELEGRAM_DATABASE_USERNAME:?Set TELEGRAM_DATABASE_USERNAME in .env}", provisioner.dig("environment", "TELEGRAM_DATABASE_USERNAME")
    assert_equal "${TELEGRAM_DATABASE_PASSWORD:?Set TELEGRAM_DATABASE_PASSWORD in .env}", provisioner.dig("environment", "TELEGRAM_DATABASE_PASSWORD")
    assert_equal provisioner.dig("environment", "TELEGRAM_DATABASE_USERNAME"), services.dig("telegram_app", "environment", "DATABASE_USERNAME")
    assert_equal provisioner.dig("environment", "TELEGRAM_DATABASE_PASSWORD"), services.dig("telegram_migrate", "environment", "DATABASE_PASSWORD")
    assert_equal "service_completed_successfully", services.dig("telegram_migrate", "depends_on", "telegram_database", "condition")
    assert_equal "service_completed_successfully", services.dig("telegram_app", "depends_on", "telegram_migrate", "condition")
  end

  test "limits Telegram service reachability to the required peer pairs" do
    compose = YAML.safe_load_file("compose.yml", aliases: true)
    services = compose.fetch("services")

    assert_equal %w[default telegram_core_adapter], services.fetch("core").fetch("networks")
    assert_equal %w[telegram_core_adapter telegram_adapter_app], services.fetch("telegram_adapter").fetch("networks")
    assert_equal %w[telegram_adapter_app telegram_nginx_app telegram_app_postgres telegram_app_mtproto], services.fetch("telegram_app").fetch("networks")
    assert_equal %w[default telegram_nginx_app], services.fetch("nginx").fetch("networks")
    assert_equal %w[default telegram_app_postgres], services.fetch("postgres").fetch("networks")

    %w[telegram_app telegram_adapter].each do |service_name|
      refute_includes services.fetch(service_name).fetch("networks"), "default"
    end

    assert_equal [ "telegram_app_postgres" ], services.fetch("telegram_migrate").fetch("networks")

    %w[telegram_core_adapter telegram_adapter_app telegram_nginx_app telegram_app_postgres telegram_app_mtproto].each do |network_name|
      assert_equal true, compose.fetch("networks").fetch(network_name).fetch("internal")
    end
  end

  test "routes Telegram through Core auth with a rebuilt trusted identity allowlist" do
    nginx = File.read("deploy/nginx/ayaya.example.conf")

    assert_includes nginx, "set $telegram_app_upstream telegram_app;"
    assert_includes nginx, "location = /m/telegram {\n      return 308 /m/telegram/;\n    }"
    assert_includes nginx, "location /m/telegram/"
    assert_includes nginx, "proxy_pass http://$telegram_app_upstream:3000;"
    assert_equal 4, nginx.scan("auth_request /internal/auth/module_access;").length

    telegram_route = nginx.match(/location \/m\/telegram\/ \{(?<body>.*?)\n    \}/m)[:body]
    assert_includes telegram_route, "proxy_pass_request_headers off;"
    %w[
      Sec-Fetch-Dest
      Sec-Fetch-Mode
      Sec-Fetch-Site
      Sec-Fetch-User
    ].each do |header|
      assert_includes telegram_route, "proxy_set_header #{header} $http_#{header.downcase.tr('-', '_')};"
    end
    %w[
      X-Ayaya-User-Id
      X-Ayaya-User-Email
      X-Ayaya-User-Display-Name
      X-Ayaya-User-Role
      X-Ayaya-Module-Key
      X-Ayaya-Request-Id
      X-Ayaya-Identity-Signature
    ].each do |header|
      assert_includes telegram_route, "proxy_set_header #{header} $ayaya_#{header.delete_prefix('X-Ayaya-').underscore.tr('-', '_')};"
    end
    assert_includes telegram_route, "auth_request_set $ayaya_identity_signature $upstream_http_x_ayaya_identity_signature;"
    assert_includes telegram_route, "proxy_set_header X-Ayaya-Identity-Signature $ayaya_identity_signature;"
    refute_includes telegram_route, "$http_x_ayaya_"
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
      PLANNING_DATABASE_NAME PLANNING_SECRET_KEY_BASE PLANNING_ADAPTER_URL
      PLANNING_ADAPTER_SECRET PLANNING_INTERNAL_STATUS_SECRET
      TELEGRAM_DATABASE_NAME TELEGRAM_ADAPTER_URL TELEGRAM_ADAPTER_SECRET
      TELEGRAM_DATABASE_USERNAME TELEGRAM_DATABASE_PASSWORD
      TELEGRAM_INTERNAL_STATUS_SECRET TELEGRAM_SECRET_KEY_BASE TELEGRAM_ENVELOPE_KEY_FILE
      TELEGRAM_TRUSTED_IDENTITY_SECRET TELEGRAM_MTPROTO_CLIENT_URL TELEGRAM_MTPROTO_CLIENT_TOKEN
    ].each do |key|
      assert_match(/^#{key}=/, template)
    end

    assert_includes template, "NOTES_ADAPTER_SECRET=replace-with-a-unique-secret"
    assert_includes template, "NOTES_INTERNAL_STATUS_SECRET=replace-with-a-unique-secret"
    assert_includes File.read(".gitignore"), "!/.env.example"
    assert_includes File.read(".dockerignore"), "!/.env.example"
  end

  test "runs Telegram app, adapter, and fault suites in CI" do
    workflow = YAML.safe_load_file(".github/workflows/ci.yml", aliases: true)
    jobs = workflow.fetch("jobs")

    assert_equal "modules/telegram/app", jobs.fetch("telegram_app_test").dig("defaults", "run", "working-directory")
    assert_equal "modules/telegram/adapter", jobs.fetch("telegram_adapter_test").dig("defaults", "run", "working-directory")
    assert_equal "modules/telegram/adapter", jobs.fetch("telegram_fault_test").dig("defaults", "run", "working-directory")
    assert_equal "bin/rails zeitwerk:check", jobs.fetch("telegram_app_test").fetch("steps").find { |step| step["name"] == "Check Telegram app autoloading" }.fetch("run")
    assert_equal "bin/brakeman --no-pager", jobs.fetch("telegram_app_test").fetch("steps").find { |step| step["name"] == "Scan Telegram app for security vulnerabilities" }.fetch("run")
    assert_equal "bin/rails db:prepare && bin/rails test", jobs.fetch("telegram_app_test").fetch("steps").find { |step| step["name"] == "Run Telegram app tests" }.fetch("run")
    assert_equal "python -m pytest -q tests/test_health_status.py", jobs.fetch("telegram_fault_test").fetch("steps").find { |step| step["name"] == "Run Telegram fault tests" }.fetch("run")
  end

  test "gates the Telegram release topology in CI" do
    workflow = YAML.safe_load_file(".github/workflows/ci.yml", aliases: true)
    release_contract = workflow.fetch("jobs").fetch("telegram_release_contract")
    steps = release_contract.fetch("steps")

    assert_equal "${{ github.workspace }}/tmp/telegram-envelope-keyring.json", release_contract.dig("env", "TELEGRAM_ENVELOPE_KEY_FILE")
    assert_equal "docker compose --env-file .env.example config --quiet", steps.find { |step| step["name"] == "Validate Compose release configuration" }.fetch("run")
    assert_includes steps.find { |step| step["name"] == "Build Telegram Adapter default test stage" }.fetch("run"), "docker build --tag ayaya-telegram-adapter-test --file modules/telegram/adapter/Dockerfile modules/telegram"
    assert_equal "docker compose --env-file .env.example build telegram_app telegram_migrate telegram_worker telegram_adapter", steps.find { |step| step["name"] == "Build Telegram Compose services" }.fetch("run")
    assert_equal "docker compose --env-file .env.example up --detach --wait --wait-timeout 180 telegram_app telegram_worker telegram_adapter", steps.find { |step| step["name"] == "Provision and health-check Telegram Compose services" }.fetch("run")
    assert_equal "docker run --rm -v \"$PWD:/repo\" -w /repo rhysd/actionlint:1.7.7", steps.find { |step| step["name"] == "Lint GitHub Actions workflow" }.fetch("run")
    assert_equal "docker run --rm -v \"$PWD/deploy/nginx/ayaya.example.conf:/etc/nginx/nginx.conf:ro\" nginx:1.27-alpine nginx -t", steps.find { |step| step["name"] == "Validate Nginx configuration" }.fetch("run")
  end

  test "excludes generated Telegram artifacts from lint and release contexts" do
    rubocop = YAML.safe_load_file(".rubocop.yml", aliases: true)

    assert_includes rubocop.dig("AllCops", "Exclude"), "modules/*/app/db/schema.rb"
    assert_includes File.read(".dockerignore"), "/graphify-out/"
    assert_includes File.read(".gitignore"), "/graphify-out/"
    assert_includes File.read("modules/telegram/app/.dockerignore"), "/graphify-out/"
    assert_includes File.read("modules/telegram/app/.gitignore"), "/graphify-out/"
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
