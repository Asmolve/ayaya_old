module Telegram
  class EnvironmentKeyProvider
    def self.available?
      ENV.fetch("TELEGRAM_ENVELOPE_KEY", "").bytesize == 32
    end

    def current
      raise KeyUnavailable unless self.class.available?

      [ ENV.fetch("TELEGRAM_ENVELOPE_KEY_ID", "env-v1"), ENV.fetch("TELEGRAM_ENVELOPE_KEY") ]
    end

    def fetch(key_id)
      current_id, key = current
      key_id == current_id ? key : nil
    end
  end
end
