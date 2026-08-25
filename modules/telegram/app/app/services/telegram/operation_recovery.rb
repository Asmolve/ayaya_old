module Telegram
  class OperationRecovery
    def self.reconcile!(account:, client:)
      new(account:, client:).call
    end

    def initialize(account:, client:)
      @account = account
      @client = client
    end

    def call
      lease = AccountLease.acquire!(account: @account, holder: "recovery-#{SecureRandom.uuid}")
      @account.operations.where(status: %w[applying reconciling cancelled]).find_each do |operation|
        operation.operation_steps.where(status: "dispatched").update_all(status: "outcome_unknown", updated_at: Time.current)
        operation.operation_steps.where(status: "outcome_unknown").find_each { |step| Reconciler.new(client: @client).reconcile(step) }
        cancel_pending_steps(operation) if operation.reload.status == "cancelled"
        if operation.reload.status == "reconciling" && operation.operation_steps.where(status: "planned").exists? && operation.operation_steps.where(status: "outcome_unknown").none?
          resume_remaining_steps(operation, lease:)
        end
      end
    ensure
      lease&.release!(holder: lease.holder)
    end

    private

    def cancel_pending_steps(operation)
      operation.operation_steps.where(status: "planned").update_all(status: "cancelled", updated_at: Time.current)
    end

    def resume_remaining_steps(operation, lease:)
      OperationExecutor.new(
        operation:,
        client: @client,
        confirmed: true,
        holder: lease.holder,
        resuming: true,
        acquire_lease: false
      ).call
    rescue PreflightConflict
      # OperationExecutor has recorded a durable conflict; recovery must not
      # turn a stale precondition into a worker-wide failure.
    end
  end
end
