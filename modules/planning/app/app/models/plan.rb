class Plan < ApplicationRecord
  belongs_to :local_user
  has_many :plan_items, dependent: :destroy

  validates :title, presence: true
end
