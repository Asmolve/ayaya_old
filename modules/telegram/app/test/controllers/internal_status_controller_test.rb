require "test_helper"

class TelegramStatusControllerTest < ActionDispatch::IntegrationTest
  setup { @old_secret = ENV["TELEGRAM_INTERNAL_STATUS_SECRET"]; ENV["TELEGRAM_INTERNAL_STATUS_SECRET"] = "status-secret" }
  teardown { ENV["TELEGRAM_INTERNAL_STATUS_SECRET"] = @old_secret }

  test "requires a bearer secret and redacts account state" do
    get "/internal/ayaya/status"
    assert_response :unauthorized

    get "/internal/ayaya/status", headers: { "Authorization" => "Bearer status-secret" }
    assert_response :success
    body = JSON.parse(response.body)
    assert_equal "telegram", body.fetch("module_key")
    assert_equal %w[app database key_management telegram], body.fetch("components").keys.sort
    refute body.to_json.match?(/session|account_id|secret/i)
  end
end
