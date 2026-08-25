require "test_helper"

class ReadOnlyImportTest < ActiveSupport::TestCase
  test "imports only metadata and persists an immutable canonical snapshot" do
    user = ModuleUser.create!(core_user_id: "1")
    account = TelegramAccount.create!(module_user: user, telegram_account_id: "account")
    client = Telegram::TestClient.new(remote_state: {
      "dialogs" => [ { "peer_kind" => "channel", "peer_id" => "10", "input_peer_ref" => { "id" => "10" }, "title" => "Projects", "username" => "projects", "metadata_hash" => "meta" } ],
      "folders" => [ { "telegram_folder_id" => 4, "title" => "Projects", "managed_by_app" => false } ],
      "app_config" => { "dialog_filters_limit_default" => 20, "dialog_filters_chats_limit_default" => 200 }
    })

    limits = Telegram::ReadOnlyImport.new(account: account, client: client).call

    assert_equal 20, limits.folder_limit
    assert_equal 1, account.dialogs.count
    assert_predicate account.reload.last_seen_at, :present?
    snapshot = account.snapshots.find_by!(kind: "import")
    assert_equal Telegram::CanonicalSnapshot::VERSION, snapshot.canonical_version
    assert_predicate snapshot.source_hash, :present?
    refute_includes snapshot.payload.to_json, "message"
  end
end
