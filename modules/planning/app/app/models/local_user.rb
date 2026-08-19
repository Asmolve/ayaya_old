class LocalUser < ApplicationRecord
  has_many :plans, dependent: :destroy
  has_many :plan_items, through: :plans

  validates :core_user_id, presence: true, uniqueness: true
end
