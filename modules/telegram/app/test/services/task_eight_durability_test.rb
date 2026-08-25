require "test_helper"

class TaskEightDurabilityTest < ActiveSupport::TestCase
  test "dry run derives managed folder members from accepted assignments and enabled rules while preserving foreign folders" do
    account = writable_account("desired-state")
    managed = managed_folder(account, id: 1, title: "Work")
    foreign = remote_folder(id: 2, title: "Telegram", managed: false)
    manual = dialog(account, kind: "channel", id: "manual", title: "Manual")
    ruled = dialog(account, kind: "bot", id: "bot", title: "Build bot")
    ignored = dialog(account, kind: "channel", id: "proposal", title: "Proposal")
    account.assignments.create!(folder: managed, peer_kind: manual.peer_kind, peer_id: manual.peer_id, source: "manual", locked: true)
    account.assignments.create!(folder: managed, peer_kind: ignored.peer_kind, peer_id: ignored.peer_id, source: "proposal", locked: false)
    account.rules.create!(rule_id: "bots", version: 1, priority: 1, target_folder: managed, condition_json: { "peer_kind" => "bot" })
    state = remote_state(folders: [ remote_folder(id: 1, title: "Work", managed: true, account_id: account.telegram_account_id), foreign ])

    operation = Telegram::OperationFactory.new(account: account, client: Telegram::TestClient.new(remote_state: state)).dry_run
    desired = operation.plan_data.fetch("expected_remote_state").fetch("folders")
    work = desired.find { |folder| folder.fetch("telegram_folder_id") == 1 }

    assert_equal foreign, desired.find { |folder| folder.fetch("telegram_folder_id") == 2 }.except("flags")
    assert_equal [ manual.input_peer_ref, ruled.input_peer_ref ].sort_by(&:to_json), work.fetch("include_peers").sort_by(&:to_json)
    refute_includes work.fetch("include_peers"), ignored.input_peer_ref
  end

  test "dry run creates one durable step for each filter write and the final order RPC" do
    account = writable_account("steps")
    first = managed_folder(account, id: 1, title: "First", revision: 2)
    second = managed_folder(account, id: 2, title: "Second", revision: 1)
    first_dialog = dialog(account, kind: "channel", id: "first", title: "First chat")
    second_dialog = dialog(account, kind: "channel", id: "second", title: "Second chat")
    account.assignments.create!(folder: first, peer_kind: first_dialog.peer_kind, peer_id: first_dialog.peer_id, source: "manual", locked: true)
    account.assignments.create!(folder: second, peer_kind: second_dialog.peer_kind, peer_id: second_dialog.peer_id, source: "manual", locked: true)
    state = remote_state(folders: [ remote_folder(id: 1, title: "First", managed: true, account_id: account.telegram_account_id), remote_folder(id: 2, title: "Second", managed: true, account_id: account.telegram_account_id) ], folder_order: [ 1, 2 ])

    operation = Telegram::OperationFactory.new(account: account, client: Telegram::TestClient.new(remote_state: state)).dry_run

    assert_equal %w[update_dialog_filter update_dialog_filter update_dialog_filters_order], operation.operation_steps.order(:sequence).pluck(:rpc)
    assert_equal 3, operation.operation_steps.count
    assert_equal [ 2, 1 ], operation.operation_steps.last.request_data.fetch("folder_order")
  end

  test "a returned dialog clears its stale marker during a completed import" do
    account = writable_account("stale-reset")
    stale = dialog(account, kind: "channel", id: "present", title: "Present")
    stale.update!(stale_at: 1.day.ago)
    state = remote_state(dialogs: [ remote_dialog(kind: "channel", id: "present", title: "Present") ])

    Telegram::ReadOnlyImport.new(account: account, client: Telegram::TestClient.new(remote_state: state)).call

    assert_nil stale.reload.stale_at
  end

  test "import persists Telegram limits for display and later preflight" do
    account = writable_account("limits")
    limits = full_limits.merge("version" => "2026-08")

    Telegram::ReadOnlyImport.new(account: account, client: Telegram::TestClient.new(remote_state: remote_state(app_config: limits))).call

    assert_equal 10, account.reload.persisted_limits.fetch("folder_limit")
    assert_equal "2026-08", account.persisted_limits.fetch("config_version")
  end

  test "regex matching is bounded and invalid timed-out patterns do not classify a dialog" do
    condition = { "regex" => "(a+)+$" }
    dialog_data = { "peer_kind" => "channel", "peer_id" => "slow", "title" => "a" * 10_000 + "!" }

    refute Telegram::SafeRegex.match?(condition.fetch("regex"), dialog_data.fetch("title"))
    result = Telegram::RuleClassifier.new.classify(dialog: dialog_data, assignments: [], rules: [ { id: "slow", priority: 1, condition:, folder_id: 1 } ])

    assert_equal :proposed, result.status
  end

  test "retention purge removes expired encrypted snapshots and scrubs expired operation payloads" do
    account = writable_account("retention")
    expired = account.snapshots.create!(snapshot_id: "expired", kind: "import", canonical_version: 2, source_hash: "expired", payload: { "private" => "data" }, retention_until: 1.minute.ago)
    operation = account.operations.create!(operation_id: "expired-operation", status: "completed", completed_at: 1.minute.ago, plan: { "private" => "data" }, retention_until: 1.minute.ago)
    operation.operation_steps.create!(telegram_account: account, step_id: "done", status: "confirmed", request_fingerprint: "r", precondition_fingerprint: "p", expected_postcondition: {})

    Telegram::RetentionPurge.new.call

    assert_nil Snapshot.find_by(id: expired.id)
    assert_equal({}, operation.reload.plan_data)
    assert_equal({}, operation.operation_steps.first.reload.error_json)
  end

  test "executor observes cancellation before acquiring a dispatch boundary" do
    account = writable_account("cancel-boundary")
    state = remote_state
    operation = account.operations.create!(operation_id: "cancelled", status: "cancelled", plan: { "preflight_fingerprint" => Telegram::CanonicalSnapshot.build(state: state).source_hash, "folder_count" => 0 })
    operation.operation_steps.create!(telegram_account: account, step_id: "never-send", request_fingerprint: "request", precondition_fingerprint: Telegram::CanonicalSnapshot.build(state: state).source_hash, expected_postcondition: state)
    client = Telegram::TestClient.new(remote_state: state)

    Telegram::OperationExecutor.new(operation: operation, client: client, confirmed: true).call

    assert_empty client.mutations
    assert_equal "cancelled", operation.reload.status
  end

  test "reconciliation treats equivalent canonical filter vectors as confirmed despite remote array ordering" do
    account = writable_account("canonical-reconcile")
    expected = remote_state(folders: [ remote_folder(id: 1, title: "One", managed: false), remote_folder(id: 2, title: "Two", managed: false) ], folder_order: [ 1, 2 ])
    operation = account.operations.create!(operation_id: "canonical", status: "reconciling", plan: {})
    step = operation.operation_steps.create!(telegram_account: account, step_id: "canonical", status: "outcome_unknown", request_fingerprint: "request", precondition_fingerprint: "before", expected_postcondition: expected)
    actual = expected.merge("folders" => expected.fetch("folders").reverse)

    assert_equal :confirmed, Telegram::Reconciler.new(client: Telegram::TestClient.new(remote_state: actual)).reconcile(step)
    assert_equal "confirmed", step.reload.status
  end

  private

  def writable_account(id)
    TelegramAccount.create!(module_user: ModuleUser.create!(core_user_id: id), telegram_account_id: "account-#{id}", read_only: false)
  end

  def managed_folder(account, id:, title:, revision: 0)
    account.folders.create!(telegram_folder_id: id, title: title, managed_by_app: true, local_revision: revision, remote_fingerprint: "managed-#{id}", ownership_record: { "account_id" => account.telegram_account_id, "telegram_folder_id" => id, "fingerprint" => "managed-#{id}" })
  end

  def dialog(account, kind:, id:, title:)
    Dialog.create!(telegram_account: account, peer_kind: kind, peer_id: id, title: title, metadata_hash: "hash-#{id}", input_peer_ref: { "id" => id, "kind" => kind })
  end

  def remote_dialog(kind:, id:, title:)
    { "peer_kind" => kind, "peer_id" => id, "title" => title, "metadata_hash" => "hash-#{id}", "input_peer_ref" => { "id" => id, "kind" => kind } }
  end

  def remote_folder(id:, title:, managed:, include_peers: [], account_id: nil)
    { "telegram_folder_id" => id, "title" => title, "emoji" => nil, "mode" => "showcase", "include_peers" => include_peers, "exclude_peers" => [], "pinned_peers" => [], "managed_by_app" => managed, "ownership_record" => managed ? { "account_id" => account_id, "telegram_folder_id" => id, "fingerprint" => "managed-#{id}" } : {}, "remote_fingerprint" => managed ? "managed-#{id}" : "foreign-#{id}" }
  end

  def remote_state(folders: [], dialogs: [], app_config: full_limits, folder_order: nil)
    { "folders" => folders, "dialogs" => dialogs, "app_config" => app_config }.tap { |state| state["folder_order"] = folder_order if folder_order }
  end

  def full_limits
    {
      "dialog_filters_limit_default" => 10,
      "dialog_filters_chats_limit_default" => 100,
      "dialogs_folder_pinned_limit_default" => 5,
      "dialog_filters_title_length_limit_default" => 12
    }
  end
end
