class Assignment < ApplicationRecord
  belongs_to :telegram_account, inverse_of: :assignments
  belongs_to :folder, optional: true, inverse_of: :assignments

  validates :peer_kind, :peer_id, :source, presence: true
  validates :peer_id, uniqueness: { scope: %i[telegram_account_id peer_kind] }
  validate :folder_belongs_to_account

  private

  def folder_belongs_to_account
    errors.add(:folder, "must belong to the same Telegram account") if folder && folder.telegram_account_id != telegram_account_id
  end
end
