class FolderProposal < ApplicationRecord
  STATUSES = %w[proposed accepted rejected].freeze

  belongs_to :telegram_account, inverse_of: :folder_proposals

  validates :proposal_id, :category, :title, :status, presence: true
  validates :proposal_id, uniqueness: { scope: :telegram_account_id }
  validates :category, uniqueness: { scope: :telegram_account_id }
  validates :status, inclusion: { in: STATUSES }

  def accept!
    update!(status: "accepted", accepted_at: Time.current)
  end
end
