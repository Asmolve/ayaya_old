module Telegram
  class RetentionPurge
    def initialize(now: Time.current)
      @now = now
    end

    def call
      ApplicationRecord.transaction do
        expired_operations.find_each do |operation|
          operation.update!(plan: EncryptedPayload.encrypt({}), retention_until: nil)
          operation.operation_steps.update_all(
            request_payload: EncryptedPayload.encrypt({}),
            expected_postcondition: {},
            error_json: {},
            updated_at: @now
          )
        end

        protected_snapshot_ids = Operation.where.not(before_snapshot_id: nil).select(:before_snapshot_id)
        Snapshot.where("retention_until <= ?", @now).where.not(id: protected_snapshot_ids).delete_all
        Snapshot.where("retention_until <= ?", @now).where(id: protected_snapshot_ids).update_all(payload: EncryptedPayload.encrypt({}), updated_at: @now)
      end
    end

    private

    def expired_operations
      Operation.where("retention_until <= ?", @now)
    end
  end
end
