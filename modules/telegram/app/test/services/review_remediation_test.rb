require "test_helper"
require "base64"
require "tempfile"

class ReviewRemediationTest < ActiveSupport::TestCase
  test "planner reports conflicts instead of changing foreign shared or externally modified folders" do
    foreign = { "telegram_folder_id" => 1, "title" => "Foreign", "managed_by_app" => false }
    shared = { "telegram_folder_id" => 2, "title" => "Shared", "managed_by_app" => true, "type" => "dialogFilterChatlist", "ownership_record" => { "account_id" => "42", "fingerprint" => "a" }, "remote_fingerprint" => "a" }
    changed = { "telegram_folder_id" => 3, "title" => "Changed", "managed_by_app" => true, "ownership_record" => { "account_id" => "42", "fingerprint" => "a" }, "remote_fingerprint" => "b" }
    desired = [ foreign.merge("title" => "Nope"), shared.merge("title" => "Nope"), changed.merge("title" => "Nope") ]

    result = Telegram::Planner.new(current_folders: [ foreign, shared, changed ], desired_folders: desired, account_id: "42").safe_diff

    assert_empty result.fetch("update")
    assert_equal %w[foreign_folder shared_folder externally_modified].sort, result.fetch("conflicts").map { |conflict| conflict.fetch("reason") }.sort
  end

  test "dynamic limits select entitlement variants and reject unknown capacity before a write" do
    limits = Telegram::DynamicLimits.from_app_config(
      "entitlement" => "premium",
      "dialog_filters_limit_default" => 10,
      "dialog_filters_limit_premium" => 20,
      "dialog_filters_chats_limit_default" => 100,
      "dialog_filters_chats_limit_premium" => 200,
      "dialogs_folder_pinned_limit_premium" => 7,
      "dialog_filters_title_length_limit_premium" => 12
    )

    assert_equal 20, limits.folder_limit
    assert_equal 200, limits.chats_per_folder_limit
    assert_equal 7, limits.pinned_limit
    assert_equal 12, limits.title_length_limit
    refute_predicate limits, :writes_blocked?
    assert_predicate Telegram::DynamicLimits.from_app_config({ "entitlement" => "mystery" }), :writes_blocked?
  end

  test "secret-file provider decrypts envelopes after a key rotation" do
    file = Tempfile.new("telegram-keys")
    file.write({ "current_key_id" => "v2", "keys" => { "v1" => Base64.strict_encode64("a" * 32), "v2" => Base64.strict_encode64("b" * 32) } }.to_json)
    file.close
    provider = Telegram::SecretFileKeyProvider.new(file.path)
    old = Telegram::EncryptedSecret.encrypt("old session", key_provider: Telegram::StaticKeyProvider.new("v1", "a" * 32))

    assert_equal [ "v2", "b" * 32 ], provider.current
    assert_equal "old session", Telegram::EncryptedSecret.decrypt(old, key_provider: provider)
  ensure
    file&.unlink
  end

  test "authentication flow keeps code and password out of persisted state" do
    account = TelegramAccount.create!(module_user: ModuleUser.create!(core_user_id: "auth"), telegram_account_id: "pending")
    client = Telegram::TestClient.new(auth_result: { "challenge_id" => "challenge", "state" => "awaiting_code" })

    Telegram::AuthenticationFlow.new(account: account, client: client, key_provider: Telegram::StaticKeyProvider.new("v1", "a" * 32)).start_phone(phone: "+79990000000", api_id: "id", api_hash: "hash")

    assert_equal "awaiting_code", account.reload.connection_state
    refute_includes account.auth_challenge.to_json, "+79990000000"
    refute_includes account.auth_challenge.to_json, "hash"
  end

  test "preflight blocks an externally changed remote state before any RPC" do
    account = writable_account("preflight")
    operation = Operation.create!(telegram_account: account, operation_id: "preflight", status: "awaiting_confirmation", plan: { "preflight_fingerprint" => "stale", "folders" => [], "title" => "Work" })
    OperationStep.create!(telegram_account: account, operation: operation, step_id: "one", request_fingerprint: "request", precondition_fingerprint: "stale", expected_postcondition: { "folders" => [] })
    client = Telegram::TestClient.new(remote_state: { "folders" => [], "app_config" => full_limits })

    assert_raises(Telegram::PreflightConflict) { Telegram::OperationExecutor.new(operation: operation, client: client, confirmed: true).call }
    assert_empty client.mutations
    assert_equal "conflicted", operation.reload.status
  end

  test "disconnect is idempotent, cancels durable work, and purges retained account data" do
    account = writable_account("disconnect")
    folder = Folder.create!(telegram_account: account, telegram_folder_id: 1, title: "Managed")
    Assignment.create!(telegram_account: account, folder: folder, peer_kind: "user", peer_id: "1", source: "manual")
    operation = Operation.create!(telegram_account: account, operation_id: "pending", status: "awaiting_confirmation", plan: { "secret" => "never retain" })
    OperationStep.create!(telegram_account: account, operation: operation, step_id: "one", request_fingerprint: "r", precondition_fingerprint: "p", expected_postcondition: {})
    client = Telegram::TestClient.new

    2.times { Telegram::DisconnectAccount.new(account: account, client: client).call }

    assert_equal 1, client.revocations
    assert_empty account.folders
    assert_empty account.operation_steps
    assert_equal "cancelled", operation.reload.status
    assert Telegram::EncryptedPayload.envelope?(operation.plan)
    assert_equal({}, operation.plan_data)
  end

  test "a timeout before dispatch leaves a durable step safe to retry without a remote write" do
    initial = { "folders" => [], "app_config" => full_limits }
    account = writable_account("before-timeout")
    operation = Operation.create!(telegram_account: account, operation_id: "before-timeout", status: "awaiting_confirmation", plan: {})
    step = OperationStep.create!(telegram_account: account, operation: operation, step_id: "one", request_fingerprint: "r", precondition_fingerprint: Telegram::CanonicalSnapshot.build(state: initial).source_hash, expected_postcondition: { "folders" => [] })
    client = Telegram::TestClient.new(remote_state: initial, fault: :timeout_before_dispatch)

    Telegram::OperationExecutor.new(operation: operation, client: client, confirmed: true).call

    assert_equal "planned", step.reload.status
    assert_empty client.mutations
    assert_equal "awaiting_confirmation", operation.reload.status
  end

  test "partial success survives a restart and reconciles only the unknown step" do
    initial = { "folders" => [], "app_config" => full_limits }
    first_state = { "folders" => [ { "id" => 1 } ], "app_config" => full_limits }
    final_state = { "folders" => [ { "id" => 1 }, { "id" => 2 } ], "app_config" => full_limits }
    account = writable_account("partial")
    operation = Operation.create!(telegram_account: account, operation_id: "partial", status: "awaiting_confirmation", plan: {})
    first = OperationStep.create!(telegram_account: account, operation: operation, step_id: "first", request_fingerprint: "r1", precondition_fingerprint: Telegram::CanonicalSnapshot.build(state: initial).source_hash, expected_postcondition: first_state)
    second = OperationStep.create!(telegram_account: account, operation: operation, step_id: "second", request_fingerprint: "r2", precondition_fingerprint: Telegram::CanonicalSnapshot.build(state: first_state).source_hash, expected_postcondition: final_state)
    client = Telegram::TestClient.new(remote_state: initial, faults: [ nil, :timeout_after_dispatch ])

    Telegram::OperationExecutor.new(operation: operation, client: client, confirmed: true).call

    assert_equal "confirmed", first.reload.status
    assert_equal "outcome_unknown", second.reload.status
    assert_equal :confirmed, Telegram::Reconciler.new(client: client).reconcile(second)
    assert_equal "completed", operation.reload.status
    assert_equal 2, client.mutations.length
  end

  test "operation payload redaction does not expose a user credential to another account scope" do
    owner = writable_account("owner-payload")
    other = writable_account("other-payload")
    operation = Operation.create!(telegram_account: owner, operation_id: "private", status: "awaiting_confirmation", plan: { "session" => "secret-session", "message" => "private text" })

    refute_includes operation.plan.to_json, "secret-session"
    assert_equal({ "session" => "[REDACTED]", "message" => "[REDACTED]" }, operation.plan_data)
    assert_nil other.operations.find_by(operation_id: operation.operation_id)
  end

  test "database composite foreign keys reject cross-account references" do
    first = writable_account("fk-first")
    second = writable_account("fk-second")
    folder = Folder.create!(telegram_account: first, telegram_folder_id: 1, title: "First")
    snapshot = Snapshot.create!(telegram_account: first, snapshot_id: "first", kind: "import", canonical_version: 2, source_hash: "hash", payload: {})
    operation = Operation.create!(telegram_account: first, operation_id: "first", status: "planned", plan: {})

    assert_invalid_foreign_key { Assignment.insert!({ telegram_account_id: second.id, folder_id: folder.id, peer_kind: "user", peer_id: "1", source: "manual", explanation: {}, created_at: Time.current, updated_at: Time.current }) }
    assert_invalid_foreign_key { Rule.insert!({ telegram_account_id: second.id, rule_id: "wrong", version: 1, priority: 1, target_folder_id: folder.id, condition_json: {}, enabled: true, created_at: Time.current, updated_at: Time.current }) }
    assert_invalid_foreign_key { Operation.insert!({ telegram_account_id: second.id, operation_id: "wrong", status: "planned", before_snapshot_id: snapshot.id, plan: {}, created_at: Time.current, updated_at: Time.current }) }
    assert_invalid_foreign_key { OperationStep.insert!({ telegram_account_id: second.id, operation_id: operation.id, step_id: "wrong", status: "planned", request_fingerprint: "r", precondition_fingerprint: "p", expected_postcondition: {}, error_json: {}, created_at: Time.current, updated_at: Time.current }) }
  end

  private

  def writable_account(id)
    TelegramAccount.create!(module_user: ModuleUser.create!(core_user_id: id), telegram_account_id: "account-#{id}", read_only: false)
  end

  def full_limits
    {
      "dialog_filters_limit_default" => 10,
      "dialog_filters_chats_limit_default" => 100,
      "dialogs_folder_pinned_limit_default" => 5,
      "dialog_filters_title_length_limit_default" => 12
    }
  end

  def assert_invalid_foreign_key(&)
    assert_raises(ActiveRecord::InvalidForeignKey) do
      ApplicationRecord.transaction(requires_new: true, &)
    end
  end
end
