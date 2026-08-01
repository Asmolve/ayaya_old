class LocalUser < ApplicationRecord
  has_many :notes, dependent: :destroy

  validates :core_user_id, presence: true, uniqueness: true
end
