class ModuleUser < ApplicationRecord
  has_one :telegram_account, dependent: :destroy

  validates :core_user_id, presence: true, uniqueness: true
end
