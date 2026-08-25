module Telegram
  class DynamicLimits
    FALLBACK_FOLDER_LIMIT = 10
    FALLBACK_CHATS_PER_FOLDER_LIMIT = 100
    FALLBACK_PINNED_LIMIT = 5
    FALLBACK_TITLE_LENGTH_LIMIT = 12

    attr_reader :folder_limit, :chats_per_folder_limit, :pinned_limit, :title_length_limit, :source, :config_hash, :config_version, :entitlement

    def self.from_app_config(config)
      config = config.deep_stringify_keys
      entitlement = config["entitlement"].to_s.presence || "default"
      supported = %w[default premium]
      values = {
        folder: lookup(config, "dialog_filters_limit", entitlement),
        chats: lookup(config, "dialog_filters_chats_limit", entitlement),
        pinned: lookup(config, "dialogs_folder_pinned_limit", entitlement),
        title: lookup(config, "dialog_filters_title_length_limit", entitlement)
      }
      unknown = !supported.include?(entitlement) || values.values.any?(&:nil?)
      new(
        values[:folder] || FALLBACK_FOLDER_LIMIT,
        values[:chats] || FALLBACK_CHATS_PER_FOLDER_LIMIT,
        values[:pinned] || FALLBACK_PINNED_LIMIT,
        values[:title] || FALLBACK_TITLE_LENGTH_LIMIT,
        source: unknown ? "fallback-v2" : "telegram_app_config",
        writes_blocked: unknown,
        config_hash: CanonicalSnapshot.build(config: config).source_hash,
        config_version: config["version"] || config["hash"] || "unknown",
        entitlement: entitlement
      )
    end

    def self.lookup(config, prefix, entitlement)
      value = config["#{prefix}_#{entitlement}"]
      return value if value.present?
      return config["#{prefix}_default"] if entitlement != "default"

      nil
    end

    def initialize(folder_limit, chats_per_folder_limit, pinned_limit, title_length_limit, source:, writes_blocked:, config_hash:, config_version:, entitlement:)
      @folder_limit = Integer(folder_limit)
      @chats_per_folder_limit = Integer(chats_per_folder_limit)
      @pinned_limit = Integer(pinned_limit)
      @title_length_limit = Integer(title_length_limit)
      @source = source
      @writes_blocked = writes_blocked
      @config_hash = config_hash
      @config_version = config_version
      @entitlement = entitlement
    end

    def writes_blocked? = @writes_blocked

    def validate!(folders:, title:, chats: 0, pinned: 0)
      raise ArgumentError, "Telegram entitlement is unknown; writes are blocked" if writes_blocked?
      raise ArgumentError, "folder title is empty" if title.to_s.strip.empty?
      raise ArgumentError, "folder title is too long" if title.to_s.each_grapheme_cluster.count > title_length_limit
      raise ArgumentError, "folder limit exceeded" if folders > folder_limit
      raise ArgumentError, "folder chat limit exceeded" if chats > chats_per_folder_limit
      raise ArgumentError, "folder pinned limit exceeded" if pinned > pinned_limit
    end

    def validate_remote_state!(state)
      folders = state.fetch("folders", []).map(&:deep_stringify_keys)
      raise ArgumentError, "folder limit exceeded" if folders.length > folder_limit

      folders.each do |folder|
        validate!(
          folders: folders.length,
          title: folder["title"].presence || "Telegram",
          chats: Array(folder["include_peers"] || folder["include"] || folder["peers"]).length,
          pinned: Array(folder["pinned_peers"] || folder["pinned"]).length
        )
      end
    end

    def to_h
      {
        "folder_limit" => folder_limit,
        "chats_per_folder_limit" => chats_per_folder_limit,
        "pinned_limit" => pinned_limit,
        "title_length_limit" => title_length_limit,
        "source" => source,
        "config_hash" => config_hash,
        "config_version" => config_version,
        "entitlement" => entitlement,
        "writes_blocked" => writes_blocked?
      }
    end
  end
end
