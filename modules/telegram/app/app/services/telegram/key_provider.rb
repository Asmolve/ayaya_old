module Telegram
  class KeyProvider
    def self.from_environment
      path = ENV["TELEGRAM_ENVELOPE_KEY_FILE"].presence
      return SecretFileKeyProvider.new(path) if path

      EnvironmentKeyProvider.new
    end

    def self.available?
      provider = from_environment
      provider.current
      true
    rescue KeyUnavailable
      false
    end
  end
end
