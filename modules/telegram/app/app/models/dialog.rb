class Dialog < ApplicationRecord
  belongs_to :telegram_account, inverse_of: :dialogs

  validates :peer_kind, :peer_id, :title, :metadata_hash, presence: true
  validates :peer_id, uniqueness: { scope: %i[telegram_account_id peer_kind] }
end
