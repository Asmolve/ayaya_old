class Snapshot < ApplicationRecord
  belongs_to :telegram_account, inverse_of: :snapshots

  validates :snapshot_id, :kind, :canonical_version, :source_hash, presence: true
  validates :snapshot_id, uniqueness: { scope: :telegram_account_id }
  before_validation :encrypt_payload

  def payload_data(key_provider: Telegram::KeyProvider.from_environment)
    return Telegram::Redactor.call(payload) unless Telegram::EncryptedPayload.envelope?(payload)

    Telegram::EncryptedPayload.decrypt(payload, key_provider:)
  end

  private

  def encrypt_payload
    self.payload = Telegram::EncryptedPayload.encrypt(payload) unless Telegram::EncryptedPayload.envelope?(payload)
  end
end
