require "test_helper"

class RetentionPurgeTest < ActiveSupport::TestCase
  test "expired retention removes operation and every sensitive step payload" do
    now = Time.zone.parse("2026-08-21 12:00:00 UTC")
    account = TelegramAccount.create!(module_user: ModuleUser.create!(core_user_id: "retention-purge"), telegram_account_id: "retention-purge")
    operation = account.operations.create!(operation_id: "retention-purge", status: "failed", plan: { "secret_plan" => "remove" }, retention_until: now)
    step = operation.operation_steps.create!(
      telegram_account: account,
      step_id: "retention-step",
      request_fingerprint: "request",
      precondition_fingerprint: "precondition",
      request_payload: { "secret_request" => "remove" },
      expected_postcondition: { "secret_postcondition" => "remove" },
      error_json: { "secret_error" => "remove" }
    )

    Telegram::RetentionPurge.new(now: now).call

    assert_equal({}, operation.reload.plan_data)
    assert_equal({}, step.reload.request_data)
    assert_equal({}, step.expected_postcondition)
    assert_equal({}, step.error_json)
  end
end
