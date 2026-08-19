class PlanItem < ApplicationRecord
  belongs_to :plan

  enum :priority, { now: "now", next: "next", later: "later" }, default: :next, validate: true

  validates :title, presence: true
  validates :position, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
end
