class TelegramAccount < ApplicationRecord
  belongs_to :module_user
  has_many :dialogs, dependent: :destroy, inverse_of: :telegram_account
  has_many :folders, dependent: :destroy, inverse_of: :telegram_account
  has_many :folder_proposals, dependent: :destroy, inverse_of: :telegram_account
  has_many :assignments, dependent: :destroy, inverse_of: :telegram_account
  has_many :rules, dependent: :destroy, inverse_of: :telegram_account
  has_many :snapshots, dependent: :destroy, inverse_of: :telegram_account
  has_many :operations, dependent: :destroy, inverse_of: :telegram_account
  has_many :operation_steps, dependent: :destroy, inverse_of: :telegram_account
  has_one :account_lease, dependent: :destroy

  validates :telegram_account_id, presence: true, uniqueness: { scope: :module_user_id }
  validates :connection_state, inclusion: { in: Telegram::AuthenticationFlow::STATES }, allow_nil: true

  def update_persisted_limits!(limits)
    update!(persisted_limits: limits.to_h, limits_updated_at: Time.current)
  end

  def rate_limited?(now: Time.current)
    rate_limited_until.present? && rate_limited_until > now
  end
end
