require "test_helper"

class IdentityAndSecurityTest < ActionDispatch::IntegrationTest
  test "rejects missing or wrong trusted identity" do
    get "/m/telegram"
    assert_response :unauthorized

    get "/m/telegram", headers: ayaya_headers(module_key: "notes")
    assert_response :unauthorized
  end

  test "rejects state changes from a cross-site origin even with identity headers" do
    post "/m/telegram/imports", headers: ayaya_headers(origin: "https://attacker.example", user_id: "1")

    assert_response :forbidden
  end

  test "rejects an unsigned identity before it can reach the UI path" do
    assert_no_difference "ModuleUser.count" do
      get "/m/telegram", headers: ayaya_headers.except("X-Ayaya-Identity-Signature")
    end

    assert_response :unauthorized
  end
end
