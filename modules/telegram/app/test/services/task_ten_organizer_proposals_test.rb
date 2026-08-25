require "test_helper"

class TaskTenOrganizerProposalsTest < ActiveSupport::TestCase
  test "a clean account exposes app-owned category folder proposals" do
    account = TelegramAccount.create!(module_user: ModuleUser.create!(core_user_id: "folder-proposal"), telegram_account_id: "folder-proposal")
    dialog = { "peer_kind" => "channel", "peer_id" => "42", "title" => "Updates", "metadata_hash" => "updates" }

    Telegram::Organizer.new(account: account).call(dialogs: [ dialog ])

    proposal = account.folder_proposals.find_by(category: "Channels")
    assert_equal "Channels", proposal&.title
    assert_equal "proposed", proposal&.status
    assignment = account.assignments.find_by!(peer_kind: "channel", peer_id: "42")
    assert_equal "Channels", assignment.explanation.fetch("proposed_folder_title")
    assert_nil assignment.folder
  end

  test "accepted category proposals become planned creates without claiming immutable ownership" do
    account = TelegramAccount.create!(module_user: ModuleUser.create!(core_user_id: "accepted-folder-proposal"), telegram_account_id: "accepted-folder-proposal", read_only: false)
    proposal = account.folder_proposals.create!(proposal_id: "channels", category: "Channels", title: "Channels", status: "proposed")
    proposal.accept!
    state = { "folders" => [], "folder_order" => [], "app_config" => limits }

    operation = Telegram::OperationFactory.new(account: account, client: Telegram::TestClient.new(remote_state: state)).dry_run

    folder = account.folders.find_by!(app_folder_id: proposal.proposal_id)
    refute folder.managed_by_app?
    assert_equal "proposed", folder.ownership_state
    assert_equal({}, folder.ownership_record)
    assert_equal "Channels", operation.plan_data.dig("diff", "create", 0, "title")
  end

  test "a category folder becomes immutable only after the create refetch matches" do
    account = TelegramAccount.create!(module_user: ModuleUser.create!(core_user_id: "confirmed-folder-proposal"), telegram_account_id: "confirmed-folder-proposal", read_only: false)
    proposal = account.folder_proposals.create!(proposal_id: "channels-confirmed", category: "Channels", title: "Channels", status: "proposed")
    proposal.accept!
    state = { "folders" => [], "folder_order" => [], "app_config" => limits }
    client = Telegram::TestClient.new(remote_state: state)
    operation = Telegram::OperationFactory.new(account: account, client: client).dry_run
    folder = account.folders.find_by!(app_folder_id: proposal.proposal_id)

    Telegram::OperationExecutor.new(operation: operation, client: client, confirmed: true).call

    assert_predicate folder.reload, :managed_by_app?
    assert_equal "confirmed", folder.ownership_state
    assert_equal account.telegram_account_id, folder.ownership_record.fetch("account_id")
    assert_predicate folder.ownership_record.fetch("fingerprint"), :present?
    assert_equal folder.ownership_record.fetch("fingerprint"), folder.remote_fingerprint
  end

  test "the dry-run preserves remote order anchors and records an explicit order diff" do
    account = TelegramAccount.create!(module_user: ModuleUser.create!(core_user_id: "order-anchors"), telegram_account_id: "order-anchors", read_only: false)
    account.folder_proposals.create!(proposal_id: "channels-order", category: "Channels", title: "Channels", status: "accepted")
    state = {
      "folders" => [ { "telegram_folder_id" => 9, "title" => "Foreign", "include_peers" => [] } ],
      "folder_order" => [ 9 ],
      "app_config" => limits
    }

    operation = Telegram::OperationFactory.new(account: account, client: Telegram::TestClient.new(remote_state: state)).dry_run

    assert_equal [ 9, 1 ], operation.plan_data.dig("diff", "order", "to")
    assert_equal [ 9 ], operation.plan_data.dig("diff", "order", "from")
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
