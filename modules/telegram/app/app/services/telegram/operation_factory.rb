require "securerandom"
require "set"

module Telegram
  class OperationFactory
    def initialize(account:, client:)
      @account = account
      @client = client
    end

    def dry_run
      state = @client.read_state.deep_stringify_keys
      limits = DynamicLimits.from_app_config(state.fetch("app_config", {}))
      materialize_accepted_folder_proposals!(state:, limits:)
      current_folders = state.fetch("folders", [])
      desired_state = DesiredStateBuilder.new(account: @account, state:).build
      desired_folders = desired_state.fetch("folders")
      planner = Planner.new(current_folders:, desired_folders:, account_id: @account.telegram_account_id, confirmed_folder_ids: confirmed_folder_ids)
      diff = planner.safe_diff
      current_order = Array(state["folder_order"]).presence || current_folders.map { |folder| FilterState.normalize(folder).fetch("telegram_folder_id") }
      desired_order = desired_state.fetch("folder_order")
      order_diff = { "from" => current_order.map(&:to_i), "to" => desired_order.map(&:to_i) } if current_order.map(&:to_i) != desired_order.map(&:to_i)
      before = snapshot!("before_apply", state)
      expected = state.merge("folders" => desired_folders, "folder_order" => desired_order)
      plan = {
        "preflight_fingerprint" => CanonicalSnapshot.build(state: state).source_hash,
        "limits" => limits.to_h,
        "folder_count" => desired_folders.length,
        "title" => desired_folders.first.to_h.fetch("title", "Telegram"),
        "diff" => diff.slice("create", "update", "delete").merge("details" => planner.detailed_diff, "order" => order_diff).compact,
        "policies" => desired_state.fetch("policies"),
        "conflicts" => diff.fetch("conflicts"),
        "expected_remote_state" => expected
      }
      fingerprint = CanonicalSnapshot.build(**plan).source_hash
      operation = @account.operations.create!(operation_id: SecureRandom.uuid, status: "awaiting_confirmation", before_snapshot: before, plan_fingerprint: fingerprint, plan: EncryptedPayload.encrypt(plan))
      create_steps!(operation, planner.durable_steps(state:, desired_order:)) if diff.fetch("conflicts").empty?
      operation
    end

    def rollback(operation)
      operation.reload
      raise PreflightConflict, "only the latest successful operation can be rolled back" unless operation.latest_successful_for_account?

      before = operation.before_snapshot
      raise PreflightConflict, "operation has no rollback snapshot" unless before

      state = @client.read_state.deep_stringify_keys
      snapshot = before.payload_data.deep_stringify_keys.fetch("state")
      diff = Planner.new(current_folders: state.fetch("folders", []), desired_folders: snapshot.fetch("folders", []), account_id: @account.telegram_account_id, confirmed_folder_ids: confirmed_folder_ids).safe_diff
      raise PreflightConflict, "rollback would change foreign or externally modified folders" if diff.fetch("conflicts").present?

      fingerprint = CanonicalSnapshot.build(state: state).source_hash
      plan = {
        "preflight_fingerprint" => fingerprint,
        "folder_count" => snapshot.fetch("folders", []).length,
        "title" => snapshot.fetch("folders", []).first.to_h["title"] || "Telegram",
        "expected_remote_state" => snapshot,
        "rollback_of" => operation.operation_id,
        "diff" => diff.slice("create", "update", "delete"),
        "conflicts" => diff.fetch("conflicts")
      }
      rollback = @account.operations.create!(operation_id: SecureRandom.uuid, status: "awaiting_confirmation", before_snapshot: snapshot!("before_rollback", state), plan_fingerprint: CanonicalSnapshot.build(**plan).source_hash, plan: EncryptedPayload.encrypt(plan))
      rollback_planner = Planner.new(current_folders: state.fetch("folders", []), desired_folders: snapshot.fetch("folders", []), account_id: @account.telegram_account_id, confirmed_folder_ids: confirmed_folder_ids)
      desired_order = Array(snapshot["folder_order"]).presence || state.fetch("folders", []).map { |folder| folder.fetch("telegram_folder_id") }
      create_steps!(rollback, rollback_planner.durable_steps(state:, desired_order:))
      rollback
    end

    private

    def snapshot!(kind, state)
      canonical = CanonicalSnapshot.build(state: state)
      @account.snapshots.create_or_find_by!(snapshot_id: "#{kind}-#{canonical.source_hash}") do |snapshot|
        snapshot.kind = kind
        snapshot.canonical_version = CanonicalSnapshot::VERSION
        snapshot.source_hash = canonical.source_hash
        snapshot.payload = EncryptedPayload.encrypt(canonical.payload)
        snapshot.retention_until = 30.days.from_now
      end
    end

    def create_steps!(operation, steps)
      steps.each_with_index do |step, sequence|
        request = step.fetch("request")
        request_fingerprint = CanonicalSnapshot.build(rpc: step.fetch("rpc"), request:).source_hash
        operation.operation_steps.create!(
          telegram_account: @account,
          sequence:,
          step_id: "#{step.fetch("rpc")}-#{sequence + 1}-#{request_fingerprint.first(12)}",
          rpc: step.fetch("rpc"),
          request_payload: EncryptedPayload.encrypt(request),
          request_fingerprint:,
          precondition_fingerprint: CanonicalSnapshot.build(state: sequence.zero? ? @client.read_state.deep_stringify_keys : steps.fetch(sequence - 1).fetch("expected_postcondition")).source_hash,
          expected_postcondition: step.fetch("expected_postcondition")
        )
      end
    end

    def materialize_accepted_folder_proposals!(state:, limits:)
      occupied_ids = state.fetch("folders", []).map { |folder| FilterState.normalize(folder).fetch("telegram_folder_id").to_i }.to_set
      @account.folder_proposals.where(status: "accepted").order(:created_at, :id).find_each do |proposal|
        next if @account.folders.exists?(app_folder_id: proposal.proposal_id)

        folder_id = (1..limits.folder_limit).find { |candidate| !occupied_ids.include?(candidate) }
        raise PreflightConflict, "no Telegram folder ID is available for #{proposal.title}" unless folder_id

        @account.folders.create!(
          app_folder_id: proposal.proposal_id,
          telegram_folder_id: folder_id,
          title: proposal.title,
          managed_by_app: false,
          ownership_state: "proposed",
          ownership_record: {},
          remote_state: {}
        )
        occupied_ids << folder_id
      end
    end

    def confirmed_folder_ids
      @confirmed_folder_ids ||= @account.folders.where(ownership_state: "confirmed").pluck(:telegram_folder_id)
    end
  end
end
