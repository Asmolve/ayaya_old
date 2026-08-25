ENV["RAILS_ENV"] ||= "test"
ENV["TELEGRAM_ENVELOPE_KEY"] ||= "t" * 32
ENV["TELEGRAM_TRUSTED_IDENTITY_SECRET"] ||= "telegram-test-identity-secret"
require_relative "../config/environment"
require "rails/test_help"

class ActiveSupport::TestCase
  parallelize(workers: 1)
end

module AyayaTestIdentity
  def ayaya_headers(user_id: "1", module_key: "telegram", origin: "http://www.example.com")
    headers = {
      "X-Ayaya-User-Id" => user_id,
      "X-Ayaya-Module-Key" => module_key,
      "X-Ayaya-User-Email" => "user#{user_id}@example.test",
      "X-Ayaya-User-Display-Name" => "User #{user_id}",
      "X-Ayaya-User-Role" => "user",
      "X-Ayaya-Request-Id" => "request-#{user_id}",
      "Origin" => origin,
      "Sec-Fetch-Site" => "same-origin"
    }
    headers["X-Ayaya-Identity-Signature"] = Telegram::TrustedIdentity.signature_for(
      headers,
      secret: ENV.fetch("TELEGRAM_TRUSTED_IDENTITY_SECRET")
    )
    headers
  end
end

class ActionDispatch::IntegrationTest
  include AyayaTestIdentity
end
