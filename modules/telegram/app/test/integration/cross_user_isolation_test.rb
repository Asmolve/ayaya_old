require "test_helper"

class CrossUserIsolationTest < ActionDispatch::IntegrationTest
  test "does not render another user's Telegram folders or operations" do
    owner = ModuleUser.create!(core_user_id: "1")
    other = ModuleUser.create!(core_user_id: "2")
    owner_account = TelegramAccount.create!(module_user: owner, telegram_account_id: "owner")
    other_account = TelegramAccount.create!(module_user: other, telegram_account_id: "other")
    Folder.create!(telegram_account: owner_account, telegram_folder_id: 1, title: "Owner folder", managed_by_app: true)
    Folder.create!(telegram_account: other_account, telegram_folder_id: 2, title: "Private folder", managed_by_app: true)
    Operation.create!(telegram_account: other_account, operation_id: "private-operation", status: "planned", plan: {})

    get "/m/telegram", headers: ayaya_headers(user_id: "1")

    assert_response :success
    assert_includes response.body, "Owner folder"
    assert_not_includes response.body, "Private folder"
    assert_not_includes response.body, "private-operation"
  end
end
