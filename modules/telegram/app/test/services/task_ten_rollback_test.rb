require "test_helper"

class TaskTenRollbackTest < ActiveSupport::TestCase
  test "rollback rejects a remotely self-claimed folder without locally confirmed ownership" do
    account = TelegramAccount.create!(module_user: ModuleUser.create!(core_user_id: "rollback-ownership"), telegram_account_id: "rollback-ownership", read_only: false)
    foreign = {
      "telegram_folder_id" => 7,
      "title" => "Claimed remotely",
      "managed_by_app" => true,
      "ownership_record" => { "account_id" => account.telegram_account_id, "fingerprint" => "claimed" },
      "remote_fingerprint" => "claimed"
    }
    state = { "folders" => [ foreign ], "folder_order" => [ 7 ], "app_config" => limits }
    before = account.snapshots.create!(snapshot_id: "before-rollback", kind: "before_apply", canonical_version: Telegram::CanonicalSnapshot::VERSION, source_hash: "before", payload: { "state" => { "folders" => [], "folder_order" => [], "app_config" => limits } })
    operation = account.operations.create!(operation_id: "completed-rollback", status: "completed", completed_at: Time.current, before_snapshot: before, plan: {})

    assert_raises(Telegram::PreflightConflict) { Telegram::OperationFactory.new(account: account, client: Telegram::TestClient.new(remote_state: state)).rollback(operation) }
  end

  private

  def limits
    {
      "dialog_filters_limit_default" => 10,
      "dialog_filters_chats_limit_default" => 100,
      "dialogs_folder_pinned_limit_default" => 5,
      "dialog_filters_title_length_limit_default" => 12
    }
  end
end
