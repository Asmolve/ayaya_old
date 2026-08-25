module Telegram
  class FilterState
    NORMALIZATION_VERSION = 1

    FILTER_KEYS = %w[
      telegram_folder_id title emoji mode include_peers exclude_peers pinned_peers
      flags managed_by_app ownership_record remote_fingerprint type shared
    ].freeze

    def self.normalize(folder)
      value = folder.deep_stringify_keys
      value["telegram_folder_id"] ||= value.delete("id")
      value["include_peers"] ||= value.delete("include") || value.delete("peers") || []
      value["exclude_peers"] ||= value.delete("exclude") || []
      value["pinned_peers"] ||= value.delete("pinned") || []
      value["flags"] ||= {}
      value["ownership_record"] ||= {}
      value.slice(*FILTER_KEYS).merge(value.except(*FILTER_KEYS))
    end

    def self.canonical(folder)
      CanonicalSnapshot.build(filter: normalize(folder)).payload.fetch("filter")
    end

    def self.peer_key(peer)
      peer.deep_stringify_keys.slice("id", "kind", "access_hash").to_json
    end
  end
end
