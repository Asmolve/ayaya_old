require "json"

module Telegram
  class EncryptedPayload
    VERSION = 2

    def self.encrypt(value, key_provider: KeyProvider.from_environment)
      EncryptedSecret.encrypt(JSON.generate(Redactor.call(value)), key_provider:).merge("version" => VERSION)
    end

    def self.decrypt(envelope, key_provider: KeyProvider.from_environment)
      JSON.parse(EncryptedSecret.decrypt(envelope, key_provider:))
    rescue JSON::ParserError
      raise KeyUnavailable, "encrypted payload was not valid JSON"
    end

    def self.envelope?(value)
      value.to_h["version"].to_i == VERSION && value.to_h["ciphertext"].present?
    end
  end
end
