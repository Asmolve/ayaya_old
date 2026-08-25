require "test_helper"

class OperationExecutorTest < ActiveSupport::TestCase
  test "records an outcome_unknown step after a post-dispatch timeout without blind retry" do
    account = account_for("1")
    operation = Operation.create!(telegram_account: account, operation_id: "op-1", status: "planned", plan: {})
    expected = { "folders" => [ { "id" => 8, "title" => "Projects" } ] }
    initial = { "folders" => [], "app_config" => full_limits }
    step = OperationStep.create!(telegram_account: account, operation: operation, step_id: "folder-8", request_fingerprint: "request", precondition_fingerprint: Telegram::CanonicalSnapshot.build(state: initial).source_hash, expected_postcondition: expected)
    client = Telegram::TestClient.new(remote_state: initial, fault: :timeout_after_dispatch)

    Telegram::OperationExecutor.new(operation: operation, client: client, holder: "test-worker", confirmed: true).call

    assert_equal "outcome_unknown", step.reload.status
    assert_equal 1, client.mutations.length
    assert_equal :confirmed, Telegram::Reconciler.new(client: client).reconcile(step)
  end

  test "does not dispatch a Telegram mutation without explicit confirmation" do
    account = account_for("2")
    operation = Operation.create!(telegram_account: account, operation_id: "op-2", status: "planned", plan: {})
    OperationStep.create!(telegram_account: account, operation: operation, step_id: "folder-9", request_fingerprint: "request", precondition_fingerprint: "before", expected_postcondition: { "folders" => [] })
    client = Telegram::TestClient.new

    assert_raises(Telegram::ConfirmationRequired) { Telegram::OperationExecutor.new(operation: operation, client: client).call }
    assert_empty client.mutations
  end

  test "read-only account cannot dispatch even after confirmation" do
    user = ModuleUser.create!(core_user_id: "3")
    account = TelegramAccount.create!(module_user: user, telegram_account_id: "account-3", read_only: true)
    operation = Operation.create!(telegram_account: account, operation_id: "op-3", status: "planned", plan: {})
    OperationStep.create!(telegram_account: account, operation: operation, step_id: "folder-10", request_fingerprint: "request", precondition_fingerprint: "before", expected_postcondition: { "folders" => [] })
    client = Telegram::TestClient.new

    assert_raises(Telegram::ReadOnlyViolation) { Telegram::OperationExecutor.new(operation: operation, client: client, confirmed: true).call }
    assert_empty client.mutations
  end

  private

  def account_for(core_user_id)
    user = ModuleUser.create!(core_user_id: core_user_id)
    TelegramAccount.create!(module_user: user, telegram_account_id: "account-#{core_user_id}", read_only: false)
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
