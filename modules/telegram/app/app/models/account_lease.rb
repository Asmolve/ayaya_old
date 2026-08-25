class AccountLease < ApplicationRecord
  belongs_to :telegram_account, inverse_of: :account_lease

  def self.acquire!(account:, holder:, now: Time.current, ttl: 5.minutes)
    transaction do
      lease = lock.find_or_initialize_by(telegram_account: account)
      raise Telegram::LeaseUnavailable if lease.persisted? && lease.expires_at > now && lease.holder != holder

      lease.update!(holder: holder, expires_at: now + ttl)
      lease
    end
  end

  def release!(holder:)
    return unless self.holder == holder

    update!(expires_at: Time.current)
  end
end
