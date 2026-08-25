require "test_helper"

class PlanningStatusControllerTest < ActionDispatch::IntegrationTest
  setup do
    @old_secret = ENV["PLANNING_INTERNAL_STATUS_SECRET"]
    ENV["PLANNING_INTERNAL_STATUS_SECRET"] = "test-internal-secret"
  end

  teardown do
    ENV["PLANNING_INTERNAL_STATUS_SECRET"] = @old_secret
  end

  test "requires the internal status secret" do
    get "/internal/ayaya/status"

    assert_response :unauthorized
  end

  test "reports a healthy database to the adapter" do
    get "/internal/ayaya/status", headers: { "Authorization" => "Bearer test-internal-secret" }

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal "planning", body.fetch("module_key")
    assert_equal "healthy", body.fetch("runtime_status")
    assert_equal "healthy", body.fetch("components").fetch("database")
    assert_equal [], body.fetch("degraded_reasons")
  end

  test "reports database failures as unavailable" do
    connection = Object.new
    connection.define_singleton_method(:execute) { |_sql| raise ActiveRecord::StatementInvalid, "database unavailable" }
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
    assert_equal "unhealthy", body.fetch("runtime_status")
    assert_equal "unhealthy", body.fetch("components").fetch("database")
    assert_equal [ "database_unavailable" ], body.fetch("degraded_reasons")
  end
end
