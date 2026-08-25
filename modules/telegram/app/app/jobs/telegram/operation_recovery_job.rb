module Telegram
  class OperationRecoveryJob < ::ApplicationJob
    queue_as :default

    def perform(telegram_account_id)
      account = TelegramAccount.find_by(id: telegram_account_id)
      return unless account

      OperationRecovery.reconcile!(account:, client: ClientRegistry.client_for(account))
    rescue LeaseUnavailable
      self.class.set(wait: 10.seconds).perform_later(telegram_account_id)
    end
  end
end
