require "test_helper"

class TaskTenWorkerTest < ActiveSupport::TestCase
  test "an explicit confirmation is recorded independently of Active Job" do
    account = TelegramAccount.create!(module_user: ModuleUser.create!(core_user_id: "worker-confirmation"), telegram_account_id: "worker-confirmation", read_only: false)
    operation = account.operations.create!(operation_id: "worker-confirmation", status: "awaiting_confirmation", plan: {})

    assert_respond_to operation, :request_execution!
  end

  test "the database worker drains confirmed work without relying on AsyncAdapter" do
    account = TelegramAccount.create!(module_user: ModuleUser.create!(core_user_id: "worker-drain"), telegram_account_id: "worker-drain", read_only: false)
    state = { "folders" => [], "folder_order" => [], "app_config" => limits }
    operation = account.operations.create!(operation_id: "worker-drain", status: "awaiting_confirmation", plan: { "preflight_fingerprint" => Telegram::CanonicalSnapshot.build(state: state).source_hash, "diff" => {} })
    operation.request_execution!
    client = Telegram::TestClient.new(remote_state: state)

    Telegram::WorkerService.new(client_provider: ->(_account) { client }).tick

    assert_equal "completed", operation.reload.status
    assert_equal 1, operation.attempt_count
  end

  test "a failed durable operation does not stop the polling worker from draining later work" do
    account = TelegramAccount.create!(module_user: ModuleUser.create!(core_user_id: "worker-isolation"), telegram_account_id: "worker-isolation", read_only: false)
    state = { "folders" => [], "folder_order" => [], "app_config" => limits }
    failed = account.operations.create!(operation_id: "worker-failed", status: "awaiting_confirmation", plan: { "preflight_fingerprint" => "stale", "diff" => {} })
    successful = account.operations.create!(operation_id: "worker-success", status: "awaiting_confirmation", plan: { "preflight_fingerprint" => Telegram::CanonicalSnapshot.build(state: state).source_hash, "diff" => {} })
    failed.request_execution!
    successful.request_execution!

    Telegram::WorkerService.new(client_provider: ->(_account) { Telegram::TestClient.new(remote_state: state) }).tick

    assert_equal "conflicted", failed.reload.status
    assert_equal "completed", successful.reload.status
  end

  test "transient worker failures use bounded exponential backoff with jitter before becoming terminal" do
    account = TelegramAccount.create!(module_user: ModuleUser.create!(core_user_id: "worker-retries"), telegram_account_id: "worker-retries", read_only: false)
    operation = account.operations.create!(operation_id: "worker-retries", status: "awaiting_confirmation", plan: {})
    clock = Time.zone.parse("2026-08-21 12:00:00 UTC")
    operation.request_execution!(now: clock)
    worker = Telegram::WorkerService.new(
      client_provider: ->(_account) { raise Telegram::ClientNotConfigured },
      now: -> { clock },
      max_attempts: 3,
      jitter: -> { 0.5 }
    )

    worker.tick
    assert_equal "awaiting_confirmation", operation.reload.status
    assert_equal 1, operation.attempt_count
    assert_equal clock + 15.seconds, operation.next_attempt_at

    clock = operation.next_attempt_at
    worker.tick
    assert_equal "awaiting_confirmation", operation.reload.status
    assert_equal 2, operation.attempt_count
    assert_equal clock + 30.seconds, operation.next_attempt_at

    clock = operation.next_attempt_at
    worker.tick
    assert_equal "failed", operation.reload.status
    assert_equal 3, operation.attempt_count
    assert_nil operation.next_attempt_at
    assert_predicate operation.completed_at, :present?
  end

  test "a FLOOD_WAIT pauses the account and schedules its operation without dispatching a write" do
    account = TelegramAccount.create!(module_user: ModuleUser.create!(core_user_id: "worker-flood-wait"), telegram_account_id: "worker-flood-wait", read_only: false)
    clock = Time.zone.parse("2026-08-21 12:00:00 UTC")
    state = { "folders" => [], "folder_order" => [], "app_config" => limits }
    operation = account.operations.create!(operation_id: "worker-flood-wait", status: "awaiting_confirmation", plan: { "preflight_fingerprint" => Telegram::CanonicalSnapshot.build(state: state).source_hash, "diff" => {} })
    operation.operation_steps.create!(
      telegram_account: account,
      step_id: "rate-limited-write",
      rpc: "update_dialog_filter",
      request_fingerprint: "rate-limited-write",
      precondition_fingerprint: Telegram::CanonicalSnapshot.build(state: state).source_hash,
      expected_postcondition: state
    )
    operation.request_execution!(now: clock)
    client = Telegram::TestClient.new(remote_state: state, fault: :flood_wait)

    Telegram::WorkerService.new(client_provider: ->(_account) { client }, now: -> { clock }).tick

    assert_equal clock + 60.seconds, account.reload.rate_limited_until
    assert_equal clock + 60.seconds, operation.reload.next_attempt_at
    assert_equal "awaiting_confirmation", operation.status
    assert_equal "planned", operation.operation_steps.first.reload.status
    assert_empty client.mutations
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
