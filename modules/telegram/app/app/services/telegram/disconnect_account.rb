module Telegram
  class DisconnectAccount
    def initialize(account:, client:)
      @account = account
      @client = client
    end

    def call
      @client.revoke_session(confirmed: true) unless @account.disconnected_at?
      ApplicationRecord.transaction do
        account = @account.lock!
        now = Time.current
        account.operation_steps.delete_all
        account.operations.update_all(status: "cancelled", plan: EncryptedPayload.encrypt({}), completed_at: now, updated_at: now)
        account.assignments.delete_all
        account.rules.delete_all
        account.dialogs.delete_all
        account.folders.delete_all
        account.snapshots.update_all(payload: EncryptedPayload.encrypt({}), retention_until: now + 30.days, updated_at: now)
        account.update!(
          encrypted_session: nil,
          encrypted_api_credentials: nil,
          auth_challenge: {},
          connection_state: "disconnected",
          read_only: true,
          disconnected_at: now
        )
      end
    end
  end
end
