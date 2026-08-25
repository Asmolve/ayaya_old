module Telegram
  class LeaseUnavailable < StandardError; end

  class OperationExecutor
    def initialize(operation:, client:, confirmed: false, holder: SecureRandom.uuid, resuming: false, acquire_lease: true)
      @operation = operation
      @client = client
      @confirmed = confirmed
      @holder = holder
      @resuming = resuming
      @acquire_lease = acquire_lease
    end

    def call
      raise ConfirmationRequired unless @confirmed
      raise ReadOnlyViolation if @operation.telegram_account.read_only?
      return if @operation.reload.status == "cancelled"

      lease = AccountLease.acquire!(account: @operation.telegram_account, holder: @holder) if @acquire_lease
      @resuming ? resume_preflight! : preflight!
      @operation.transition_to!("applying")
      @operation.operation_steps.order(:sequence, :created_at).each do |step|
        break unless @operation.reload.status == "applying"
        dispatch(step) if step.status == "planned"
      end
      @operation.transition_to!("completed") if @operation.operation_steps.where.not(status: "confirmed").none?
    rescue PreflightConflict
      @operation.transition_to!("conflicted") unless @operation.status == "conflicted"
      raise
    rescue FloodWait
      @operation.transition_to!("awaiting_confirmation") if @operation.persisted? && @operation.status == "applying"
      raise
    rescue StandardError
      @operation.transition_to!("failed") if @operation.persisted? && !%w[reconciling cancelled].include?(@operation.status)
      raise
    ensure
      lease&.release!(holder: @holder)
    end

    private

    def dispatch(step)
      state = stringify(@client.read_state)
      expected_precondition = step.precondition_fingerprint
      if expected_precondition.present? && expected_precondition != CanonicalSnapshot.build(state: state).source_hash
        raise PreflightConflict, "remote state changed before #{step.step_id}"
      end

      validate_step_write!(step, state)

      step.with_lock do
        return unless step.status == "planned" && @operation.reload.status == "applying"

        step.update!(status: "dispatched", error_json: {})
      end
      @client.apply(plan: step.request_data.merge("rpc" => step.rpc, "expected_postcondition" => step.expected_postcondition), confirmed: @confirmed)
      confirm_from_refetch!(step)
    rescue DispatchNotStarted => error
      step.update!(status: "planned", error_json: Redactor.call({ "class" => error.class.name, "message" => error.message }))
      @operation.transition_to!("awaiting_confirmation")
    rescue FloodWait
      step.update!(status: "planned", error_json: {})
      @operation.transition_to!("awaiting_confirmation")
      raise
    rescue Timeout::Error, OutcomeUnknown
      step.update!(status: "outcome_unknown")
      @operation.transition_to!("reconciling")
    rescue StandardError => error
      step.update!(status: "failed", error_json: Redactor.call({ "class" => error.class.name, "message" => error.message })) unless error.is_a?(PreflightConflict)
      raise
    end

    def preflight!
      state = stringify(@client.read_state)
      fingerprint = CanonicalSnapshot.build(state: state).source_hash
      planned_fingerprint = @operation.plan_data["preflight_fingerprint"]
      raise PreflightConflict, "remote state no longer matches the reviewed plan" if planned_fingerprint.present? && planned_fingerprint != fingerprint

      limits = DynamicLimits.from_app_config(state.fetch("app_config", {}))
      plan = @operation.plan_data.deep_stringify_keys
      limits.validate!(
        folders: Integer(plan.fetch("folder_count", state.fetch("folders", []).length)),
        title: plan.fetch("title", "Telegram"),
        chats: Integer(plan.fetch("chat_count", 0)),
        pinned: Integer(plan.fetch("pinned_count", 0))
      )
      raise PreflightConflict, "plan includes unresolved folder conflicts" if plan.fetch("conflicts", []).present?
      raise PreflightConflict, "operation has no durable write steps" if @operation.operation_steps.none? && plan.fetch("diff", {}).values.any?(&:present?)
    end

    def resume_preflight!
      step = @operation.operation_steps.where(status: "planned").order(:sequence, :created_at).first
      return unless step

      state = stringify(@client.read_state)
      expected_fingerprint = step.precondition_fingerprint
      actual_fingerprint = CanonicalSnapshot.build(state: state).source_hash
      raise PreflightConflict, "remote state changed before resuming #{step.step_id}" if expected_fingerprint.present? && expected_fingerprint != actual_fingerprint

      validate_step_write!(step, state)
    end

    def confirm_from_refetch!(step)
      actual = stringify(@client.read_state)
      expected = stringify(step.expected_postcondition)
      unless StateComparison.equivalent?(actual, expected)
        step.update!(status: "outcome_unknown")
        @operation.transition_to!("reconciling")
        return
      end

      fingerprint = CanonicalSnapshot.build(state: actual).source_hash
      confirm_folder_ownership_from_refetch!(step, actual)
      step.update!(status: "confirmed", result_fingerprint: fingerprint)
      checkpoint!(step, actual, fingerprint)
    end

    def validate_step_write!(step, state)
      limits = DynamicLimits.from_app_config(state.fetch("app_config", {}))
      limits.validate_remote_state!(stringify(step.expected_postcondition))
    end

    def checkpoint!(step, state, fingerprint)
      @operation.telegram_account.snapshots.create_or_find_by!(snapshot_id: "checkpoint-#{@operation.operation_id}-#{step.step_id}-#{fingerprint}") do |snapshot|
        snapshot.kind = "checkpoint"
        snapshot.canonical_version = CanonicalSnapshot::VERSION
        snapshot.source_hash = fingerprint
        snapshot.payload = EncryptedPayload.encrypt(state)
        snapshot.retention_until = 30.days.from_now
      end
    end

    def confirm_folder_ownership_from_refetch!(step, actual)
      request = step.request_data.deep_stringify_keys
      return unless request["action"] == "create"

      requested = FilterState.normalize(request.fetch("folder"))
      remote = actual.fetch("folders", []).map { |folder| FilterState.normalize(folder) }.find do |folder|
        folder.fetch("telegram_folder_id").to_s == requested.fetch("telegram_folder_id").to_s
      end
      return unless remote

      folder = @operation.telegram_account.folders.find_by(telegram_folder_id: requested.fetch("telegram_folder_id"))
      return unless folder&.ownership_state == "proposed"

      fingerprint = Ownership.fingerprint_for(remote)
      folder.update!(
        title: remote.fetch("title"),
        emoji: remote["emoji"],
        mode: remote.fetch("mode", "showcase"),
        managed_by_app: true,
        ownership_state: "confirmed",
        ownership_record: {
          "account_id" => @operation.telegram_account.telegram_account_id,
          "telegram_folder_id" => remote.fetch("telegram_folder_id"),
          "fingerprint" => fingerprint
        },
        remote_fingerprint: fingerprint,
        remote_state: remote
      )
    end

    def stringify(value)
      value.deep_stringify_keys
    end
  end
end
