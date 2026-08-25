module Telegram
  class StateComparison
    def self.equivalent?(left, right)
      fingerprint(left) == fingerprint(right)
    end

    def self.fingerprint(state)
      canonical_state = state.deep_stringify_keys
      canonical_state["folders"] = canonical_state.fetch("folders", []).map { |folder| FilterState.canonical(folder) }.sort_by { |folder| folder.fetch("telegram_folder_id").to_s }
      CanonicalSnapshot.build(state: canonical_state).source_hash
    end
  end
end
