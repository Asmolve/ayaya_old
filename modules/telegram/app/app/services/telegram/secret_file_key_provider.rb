require "base64"
require "json"

module Telegram
  # Docker secrets/KMS agents can atomically replace this file.  Retaining all
  # active key IDs allows old envelopes to be decrypted during rotation.
  class SecretFileKeyProvider
    def self.available?(path = ENV["TELEGRAM_ENVELOPE_KEY_FILE"])
      path.present? && File.file?(path) && new(path).valid?
    rescue JSON::ParserError, ArgumentError
      false
    end

    def initialize(path)
      @path = path
    end

    def valid?
      current
      true
    rescue KeyUnavailable
      false
    end

    def current
      document = load_document
      key_id = document.fetch("current_key_id")
      [ key_id, key_for(document, key_id) ]
    rescue KeyError, ArgumentError
      raise KeyUnavailable, "current envelope key is unavailable"
    end

    def fetch(key_id)
      key_for(load_document, key_id)
    rescue KeyError, ArgumentError
      nil
    end

    private

    def load_document
      JSON.parse(File.read(@path)).deep_stringify_keys
    rescue Errno::ENOENT, JSON::ParserError
      raise KeyUnavailable, "envelope key file is unavailable"
    end

    def key_for(document, key_id)
      encoded = document.fetch("keys").fetch(key_id.to_s)
      key = Base64.strict_decode64(encoded)
      raise ArgumentError unless key.bytesize == 32

      key
    end
  end
end
