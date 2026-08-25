require "base64"
require "openssl"

module Telegram
  class EncryptedSecret
    def self.encrypt(plaintext, key_provider:)
      key_id, key = key_provider.current
      cipher = OpenSSL::Cipher.new("aes-256-gcm").encrypt
      cipher.key = key
      nonce = cipher.random_iv
      ciphertext = cipher.update(plaintext) + cipher.final
      { "version" => 2, "algorithm" => "aes-256-gcm", "key_id" => key_id, "nonce" => Base64.strict_encode64(nonce), "ciphertext" => Base64.strict_encode64(ciphertext), "tag" => Base64.strict_encode64(cipher.auth_tag) }
    end

    def self.decrypt(envelope, key_provider:)
      key = key_provider.fetch(envelope.fetch("key_id"))
      raise KeyUnavailable if key.nil?

      cipher = OpenSSL::Cipher.new("aes-256-gcm").decrypt
      cipher.key = key
      cipher.iv = Base64.strict_decode64(envelope.fetch("nonce"))
      cipher.auth_tag = Base64.strict_decode64(envelope.fetch("tag"))
      cipher.update(Base64.strict_decode64(envelope.fetch("ciphertext"))) + cipher.final
    rescue OpenSSL::Cipher::CipherError
      raise KeyUnavailable, "encrypted value authentication failed"
    end
  end
end
