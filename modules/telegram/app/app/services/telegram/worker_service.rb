module Telegram
  # Startup contract: run `bin/telegram_worker` as one long-lived module-owned
  # process. It polls PostgreSQL every TELEGRAM_WORKER_POLL_INTERVAL seconds,
  # recovers interrupted operations every TELEGRAM_RECOVERY_INTERVAL seconds,
  # and purges expired retained data every TELEGRAM_RETENTION_INTERVAL seconds.
  # The durable source of truth is Operation, never an Active Job adapter.
  class WorkerService
    DEFAULT_POLL_INTERVAL = 2.seconds
    DEFAULT_RECOVERY_INTERVAL = 30.seconds
    DEFAULT_RETENTION_INTERVAL = 1.hour
    DEFAULT_LOCK_DURATION = 1.minute
    DEFAULT_MAX_ATTEMPTS = 3
    DEFAULT_RETRY_DELAY = 10.seconds

    def initialize(client_provider: ->(account) { ClientRegistry.client_for(account) }, now: -> { Time.current }, poll_interval: ENV.fetch("TELEGRAM_WORKER_POLL_INTERVAL", DEFAULT_POLL_INTERVAL).to_f, recovery_interval: ENV.fetch("TELEGRAM_RECOVERY_INTERVAL", DEFAULT_RECOVERY_INTERVAL).to_f, retention_interval: ENV.fetch("TELEGRAM_RETENTION_INTERVAL", DEFAULT_RETENTION_INTERVAL).to_f, max_attempts: DEFAULT_MAX_ATTEMPTS, jitter: -> { rand })
      @client_provider = client_provider
      @now = now
      @poll_interval = poll_interval
      @recovery_interval = recovery_interval
      @retention_interval = retention_interval
      @max_attempts = max_attempts
      @jitter = jitter
      @last_recovery_at = nil
      @last_retention_at = nil
    end

    def run
      loop do
        tick
        sleep @poll_interval
      end
    end

    def tick
      recover_interrupted_operations if due?(@last_recovery_at, @recovery_interval)
      purge_retained_data if due?(@last_retention_at, @retention_interval)
      due_operations.each { |operation| execute(operation) }
    end

    private

    def due_operations
      Operation.joins(:telegram_account).where(status: "awaiting_confirmation")
        .where.not(execution_requested_at: nil)
        .where("next_attempt_at IS NULL OR next_attempt_at <= ?", now)
        .where("worker_locked_until IS NULL OR worker_locked_until <= ?", now)
        .where("telegram_accounts.rate_limited_until IS NULL OR telegram_accounts.rate_limited_until <= ?", now)
        .order(:next_attempt_at, :id)
    end

    def execute(operation)
      return unless claim(operation)

      OperationExecutor.new(operation: operation, client: @client_provider.call(operation.telegram_account), confirmed: true, holder: "worker-#{Process.pid}-#{SecureRandom.uuid}").call
    rescue LeaseUnavailable
      retry_later(operation)
    rescue FloodWait => error
      pause_for_rate_limit(operation, error)
    rescue ClientNotConfigured, ClientResponseError
      retry_later(operation)
    rescue StandardError => error
      Rails.logger.warn("telegram durable worker operation=#{operation.operation_id} failed=#{error.class.name}")
    ensure
      release(operation)
    end

    def claim(operation)
      operation.with_lock do
        operation.reload.status == "awaiting_confirmation" &&
          operation.execution_requested_at.present? &&
          (operation.next_attempt_at.nil? || operation.next_attempt_at <= now) &&
          (operation.worker_locked_until.nil? || operation.worker_locked_until <= now) &&
          operation.update!(worker_locked_until: now + DEFAULT_LOCK_DURATION, attempt_count: operation.attempt_count + 1)
      end
    end

    def retry_later(operation)
      operation.with_lock do
        operation.reload
        return unless operation.status == "awaiting_confirmation"

        if operation.attempt_count >= @max_attempts
          operation.update!(status: "failed", completed_at: now, next_attempt_at: nil)
        else
          operation.update!(next_attempt_at: now + retry_delay(operation.attempt_count))
        end
      end
    end

    def pause_for_rate_limit(operation, error)
      retry_at = now + error.wait_seconds.seconds
      account = operation.telegram_account
      account.with_lock do
        rate_limited_until = [ account.rate_limited_until, retry_at ].compact.max
        account.update!(rate_limited_until:)
      end
      operation.with_lock do
        operation.reload
        return unless operation.status == "awaiting_confirmation"

        operation.update!(next_attempt_at: [ operation.next_attempt_at, retry_at ].compact.max)
      end
    end

    def retry_delay(attempt)
      base_delay = DEFAULT_RETRY_DELAY * (2**(attempt - 1))
      base_delay * (1 + @jitter.call.clamp(0.0, 1.0))
    end

    def release(operation)
      operation.update_column(:worker_locked_until, nil) if operation&.persisted?
    end

    def recover_interrupted_operations
      TelegramAccount.joins(:operations).where(operations: { status: %w[applying reconciling cancelled] }).distinct.find_each do |account|
        OperationRecovery.reconcile!(account:, client: @client_provider.call(account))
      rescue LeaseUnavailable, ClientNotConfigured, ClientResponseError
        next
      end
      @last_recovery_at = now
    end

    def purge_retained_data
      RetentionPurge.new(now: now).call
      @last_retention_at = now
    end

    def due?(last_run_at, interval)
      last_run_at.nil? || last_run_at + interval.seconds <= now
    end

    def now
      @now.call
    end
  end
end
