require "openssl"

module Telegram
  class TrustedIdentity
    FIELDS = %w[X-Ayaya-User-Id X-Ayaya-Module-Key X-Ayaya-User-Email X-Ayaya-User-Display-Name X-Ayaya-User-Role X-Ayaya-Request-Id].freeze

    def self.valid?(request)
      secret = ENV["TELEGRAM_TRUSTED_IDENTITY_SECRET"].to_s
      signature = request.headers["X-Ayaya-Identity-Signature"].to_s
      return false if secret.blank? || signature.blank?

      expected = signature_for(request.headers, secret: secret)
      signature.bytesize == expected.bytesize && ActiveSupport::SecurityUtils.secure_compare(signature, expected)
    end

    def self.signature_for(headers, secret:)
      values = FIELDS.map { |field| headers[field].to_s }
      OpenSSL::HMAC.hexdigest("SHA256", secret, values.join("\n"))
    end
  end
end
