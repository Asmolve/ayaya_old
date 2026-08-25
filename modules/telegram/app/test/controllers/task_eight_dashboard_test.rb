require "test_helper"

class TaskEightDashboardTest < ActionDispatch::IntegrationTest
  test "dashboard renders persisted limits, editable proposals, and the per-RPC diff" do
    user = ModuleUser.create!(core_user_id: "dashboard")
    account = TelegramAccount.create!(module_user: user, telegram_account_id: "dashboard-account", connection_state: "authenticated", read_only: false, persisted_limits: { "folder_limit" => 10, "chats_per_folder_limit" => 100, "pinned_limit" => 5, "title_length_limit" => 12, "source" => "telegram_app_config" })
    folder = account.folders.create!(telegram_folder_id: 1, title: "Work", managed_by_app: true)
    dialog = account.dialogs.create!(peer_kind: "channel", peer_id: "proposal", title: "Proposal", metadata_hash: "proposal", input_peer_ref: { "id" => "proposal" })
    account.assignments.create!(folder: folder, peer_kind: dialog.peer_kind, peer_id: dialog.peer_id, source: "proposal", confidence: 0.65, explanation: { "used_features" => [ "base_category" ] })
    operation = account.operations.create!(operation_id: "reviewable", status: "awaiting_confirmation", plan: { "diff" => { "create" => [], "update" => [ { "telegram_folder_id" => 1, "title" => "Work" } ], "delete" => [], "order" => [ 1 ] } })
    operation.operation_steps.create!(telegram_account: account, sequence: 0, step_id: "filter", rpc: "update_dialog_filter", request_fingerprint: "request", precondition_fingerprint: "before", expected_postcondition: {})

    get "/m/telegram", headers: ayaya_headers(user_id: "dashboard")

    assert_response :success
    assert_includes response.body, "Current Telegram limits"
    assert_includes response.body, "Accept proposal"
    assert_includes response.body, "Per-RPC execution plan"
    assert_includes response.body, "update_dialog_filter"
  end

  test "dashboard shows a bounded account pause, safe rule editing fields, and official session revocation instructions" do
    user = ModuleUser.create!(core_user_id: "dashboard-safety")
    account = TelegramAccount.create!(
      module_user: user,
      telegram_account_id: "dashboard-safety-account",
      connection_state: "authenticated",
      read_only: false,
      rate_limited_until: 10.minutes.from_now
    )
    folder = account.folders.create!(telegram_folder_id: 1, title: "Work", managed_by_app: true)
    rule = account.rules.create!(rule_id: "work", version: 1, priority: 1, target_folder: folder, condition_json: { "username" => "work" }, enabled: false)

    get "/m/telegram", headers: ayaya_headers(user_id: "dashboard-safety")

    assert_response :success
    assert_includes response.body, "Telegram pause active"
    assert_select "form[action='#{telegram_rule_path(rule)}'] input[name='rule[condition_json][username]'][value='work']"
    assert_select "form[action='#{telegram_rule_path(rule)}'] input[name='rule[enabled]'][type='checkbox']"
    assert_select "a[href='https://telegram.org/faq#q-my-phone-was-stolen-what-do-i-do']", text: "Official Telegram session-revocation instructions"
  end
end
