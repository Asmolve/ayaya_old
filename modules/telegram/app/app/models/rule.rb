class Rule < ApplicationRecord
  belongs_to :telegram_account, inverse_of: :rules
  belongs_to :target_folder, class_name: "Folder", optional: true, inverse_of: :targeting_rules

  validates :rule_id, :priority, presence: true
  validates :version, numericality: { only_integer: true, greater_than: 0 }
  validate :target_folder_belongs_to_account
  validate :condition_schema

  private

  def target_folder_belongs_to_account
    errors.add(:target_folder, "must belong to the same Telegram account") if target_folder && target_folder.telegram_account_id != telegram_account_id
  end

  def condition_schema
    condition = condition_json.to_h.stringify_keys
    allowed = %w[peer_id username title regex peer_kind keywords language unread manual_list]
    errors.add(:condition_json, "must include at least one predicate") unless condition.any? { |_key, value| value == false || value.present? }
    errors.add(:condition_json, "contains unsupported predicates") if (condition.keys - allowed).any?
    regex = condition["regex"]
    errors.add(:condition_json, "regex is too long") if regex.present? && regex.length > 256
    errors.add(:condition_json, "regex uses unsupported constructs") if regex.to_s.match?(/\(\?|\\[1-9]/)
    errors.add(:condition_json, "regex is invalid") if regex.present? && !Telegram::SafeRegex.valid?(regex)
  end
end
