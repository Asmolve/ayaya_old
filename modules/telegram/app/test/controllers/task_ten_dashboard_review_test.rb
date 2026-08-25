require "test_helper"

class TaskTenDashboardReviewTest < ActionDispatch::IntegrationTest
  test "proposal review supports search, filters, bulk actions, conflicts, progress, limits, and complete diffs" do
    user = ModuleUser.create!(core_user_id: "task-ten-dashboard")
    account = TelegramAccount.create!(module_user: user, telegram_account_id: "task-ten-dashboard", connection_state: "authenticated", read_only: false, last_seen_at: Time.zone.parse("2026-08-21 12:00:00 UTC"), persisted_limits: { "folder_limit" => 10, "chats_per_folder_limit" => 100, "pinned_limit" => 5, "title_length_limit" => 12, "source" => "telegram_app_config" })
    folder = account.folders.create!(telegram_folder_id: 1, title: "Work", managed_by_app: true, ownership_state: "confirmed")
    matching = account.dialogs.create!(peer_kind: "channel", peer_id: "match", title: "Find me", username: "needle", avatar_url: "https://cdn.example.test/avatar.png", metadata_hash: "match", input_peer_ref: { "id" => "match", "kind" => "channel" })
    hidden = account.dialogs.create!(peer_kind: "user", peer_id: "hidden", title: "Do not show", metadata_hash: "hidden", input_peer_ref: { "id" => "hidden", "kind" => "user" })
    account.assignments.create!(folder: folder, peer_kind: matching.peer_kind, peer_id: matching.peer_id, source: "proposal", confidence: 0.65, explanation: { "classification" => "conflicted", "used_features" => [ "base_category" ], "matched_rule_ids" => [ "same-priority" ] })
    account.assignments.create!(folder: folder, peer_kind: hidden.peer_kind, peer_id: hidden.peer_id, source: "proposal", confidence: 0.92, explanation: { "classification" => "proposed" })
    operation = account.operations.create!(operation_id: "dashboard-progress", status: "awaiting_confirmation", plan: { "diff" => { "create" => [ { "telegram_folder_id" => 2, "title" => "Channels", "flags" => { "contacts" => false }, "include_peers" => [ { "id" => "match", "kind" => "channel" } ], "exclude_peers" => [], "pinned_peers" => [] } ], "update" => [], "delete" => [], "details" => [ { "telegram_folder_id" => 1, "fields" => { "emoji" => { "from" => nil, "to" => "💼" }, "flags" => { "from" => {}, "to" => { "groups" => true } } }, "chats_added" => [ { "id" => "match", "kind" => "channel" } ], "chats_removed" => [], "order_changed" => true } ], "conflicts" => [ { "reason" => "foreign_folder" } ] } })
    operation.operation_steps.create!(telegram_account: account, sequence: 0, step_id: "confirmed", status: "confirmed", request_fingerprint: "confirmed", precondition_fingerprint: "before", expected_postcondition: {})
    operation.operation_steps.create!(telegram_account: account, sequence: 1, step_id: "pending", status: "planned", request_fingerprint: "pending", precondition_fingerprint: "before", expected_postcondition: {})

    get "/m/telegram", params: { q: "needle", proposal_filter: "conflicts" }, headers: ayaya_headers(user_id: "task-ten-dashboard")

    assert_response :success
    assert_includes response.body, "Find me"
    assert_includes response.body, "avatar.png"
    refute_includes response.body, "Do not show"
    assert_includes response.body, "Bulk actions"
    assert_includes response.body, "Block proposal"
    assert_includes response.body, "Why?"
    assert_includes response.body, "Conflict"
    assert_includes response.body, "Progress: 1 / 2"
    assert_includes response.body, "Remaining capacity"
    assert_includes response.body, "Last sync / Последняя синхронизация"
    assert_includes response.body, "Stop operation / Остановить операцию"
    assert_includes response.body, "free / свободно"
    assert_includes response.body, "Accept / Принять"
    assert_includes response.body, "Change / Изменить"
    assert_includes response.body, "Skip / Пропустить"
    assert_includes response.body, "Block / Заблокировать"
    assert_includes response.body, "flags"
    assert_includes response.body, "Confirm ("
    assert_includes response.body, "foreign_folder"
  end
end
