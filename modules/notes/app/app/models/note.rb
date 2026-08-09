class Note < ApplicationRecord
  belongs_to :local_user

  enum :entry_type, { regular: "regular", diary: "diary" }, default: :regular

  has_rich_text :diary_content

  validates :title, presence: true
  validates :start_date, :end_date, presence: true, if: :diary?
  validates :start_date, uniqueness: { scope: %i[local_user_id end_date],
                                      message: "has already been taken for this range" }, if: :diary?

  validate :diary_dates_are_in_order

  private

  def diary_dates_are_in_order
    return unless diary? && start_date.present? && end_date.present? && start_date > end_date

    errors.add(:end_date, "must be on or after start date")
  end
end
