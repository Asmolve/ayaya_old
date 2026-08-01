require "test_helper"

class Internal::Ayaya::StatusControllerTest < ActionDispatch::IntegrationTest
  setup do
    @old_secret = ENV["NOTES_INTERNAL_STATUS_SECRET"]
    ENV["NOTES_INTERNAL_STATUS_SECRET"] = "test-internal-secret"
  end

  teardown do
    ENV["NOTES_INTERNAL_STATUS_SECRET"] = @old_secret
  end

  test "requires internal status secret" do
    get "/internal/ayaya/status"

    assert_response :unauthorized
  end

  test "rejects requests when internal status secret is missing" do
    ENV.delete("NOTES_INTERNAL_STATUS_SECRET")

    get "/internal/ayaya/status", headers: { "Authorization" => "Bearer test-internal-secret" }

    assert_response :unauthorized
  end

  test "rejects a wrong-length token without raising" do
    get "/internal/ayaya/status", headers: { "Authorization" => "Bearer wrong" }

    assert_response :unauthorized
  end

  test "returns healthy status when database is available" do
    get "/internal/ayaya/status", headers: { "Authorization" => "Bearer test-internal-secret" }

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal "notes", body.fetch("module_key")
    assert_equal "healthy", body.fetch("runtime_status")
    assert_equal "healthy", body.fetch("components").fetch("app")
    assert_equal "healthy", body.fetch("components").fetch("database")
    assert_equal [], body.fetch("degraded_reasons")
    assert_match(/Z\z/, body.fetch("checked_at"))
  end

  test "does not require Ayaya user headers" do
    get "/internal/ayaya/status", headers: {
      "Authorization" => "Bearer test-internal-secret",
      "X-Ayaya-User-Id" => "1"
    }

    assert_response :success
  end

  test "reports database failure as unavailable" do
    connection = Object.new
    connection.define_singleton_method(:execute) do |_sql|
      raise ActiveRecord::StatementInvalid, "database unavailable"
    end

    base_singleton = ActiveRecord::Base.singleton_class
    original_connection = base_singleton.instance_method(:connection)
    base_singleton.send(:define_method, :connection) { connection }

    begin
      get "/internal/ayaya/status", headers: { "Authorization" => "Bearer test-internal-secret" }
    ensure
      base_singleton.send(:define_method, :connection, original_connection)
    end

    assert_response :service_unavailable
    body = JSON.parse(response.body)
    assert_equal "notes", body.fetch("module_key")
    assert_equal "unhealthy", body.fetch("runtime_status")
    assert_equal "healthy", body.fetch("components").fetch("app")
    assert_equal "unhealthy", body.fetch("components").fetch("database")
    assert_equal [ "database_unavailable" ], body.fetch("degraded_reasons")
  end
end
