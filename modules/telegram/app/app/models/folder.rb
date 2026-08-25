class Folder < ApplicationRecord
  belongs_to :telegram_account, inverse_of: :folders
  has_many :assignments, dependent: :nullify, inverse_of: :folder
  has_many :targeting_rules, class_name: "Rule", foreign_key: :target_folder_id, inverse_of: :target_folder, dependent: :nullify

  validates :telegram_folder_id, :title, presence: true
  validates :telegram_folder_id, uniqueness: { scope: :telegram_account_id }
  before_validation :preserve_confirmed_legacy_ownership

  def ownership_confirmed?
    managed_by_app? && ownership_record.fetch("account_id", nil) == telegram_account_id.to_s && ownership_record["fingerprint"].present?
  end

  def externally_modified?(remote_fingerprint)
    remote_fingerprint != self.remote_fingerprint
  end

  private

  def preserve_confirmed_legacy_ownership
    record = ownership_record.to_h.stringify_keys
    return unless ownership_state == "foreign" &&
      managed_by_app? &&
      record["account_id"] == telegram_account&.telegram_account_id &&
      record["telegram_folder_id"].to_s == telegram_folder_id.to_s &&
      record["fingerprint"].present? &&
      record["fingerprint"] == remote_fingerprint

    self.ownership_state = "confirmed"
  end
end
