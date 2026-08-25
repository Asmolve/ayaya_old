require "test_helper"

class CsrfProtectionTest < ActionDispatch::IntegrationTest
  test "rejects same-origin state changes without a synchronizer token" do
    user = ModuleUser.create!(core_user_id: "1")
    TelegramAccount.create!(module_user: user, telegram_account_id: "account")

    post "/m/telegram/imports", headers: ayaya_headers.except("Origin")

    assert_response :unprocessable_entity
  end
end
