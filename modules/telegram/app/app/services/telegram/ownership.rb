module Telegram
  module Ownership
    def self.fingerprint_for(folder)
      CanonicalSnapshot.build(filter: FilterState.canonical(folder)).source_hash
    end

    def self.mutable?(folder, account_id: nil)
      record = folder["ownership_record"].to_h.stringify_keys
      folder["managed_by_app"] &&
        folder["type"] != "dialogFilterChatlist" &&
        !folder["shared"] &&
        record["account_id"].present? &&
        (account_id.nil? || record["account_id"].to_s == account_id.to_s) &&
        record["telegram_folder_id"].to_s == folder["telegram_folder_id"].to_s &&
        record["fingerprint"].present? &&
        ActiveSupport::SecurityUtils.secure_compare(record["fingerprint"].to_s, folder["remote_fingerprint"].to_s)
    end

    def self.conflict_reason(folder, account_id:)
      return "shared_folder" if folder["type"] == "dialogFilterChatlist" || folder["shared"]
      return "foreign_folder" unless folder["managed_by_app"]
      return "account_mismatch" unless folder.dig("ownership_record", "account_id").to_s == account_id.to_s
      return "missing_ownership" if folder.dig("ownership_record", "fingerprint").blank?
      return "externally_modified" unless mutable?(folder, account_id: account_id)

      nil
    end
  end
end
