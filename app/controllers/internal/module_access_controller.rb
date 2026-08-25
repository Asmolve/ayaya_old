require "openssl"

module Internal
  class ModuleAccessController < ApplicationController
    TELEGRAM_IDENTITY_FIELDS = %w[
      X-Ayaya-User-Id
      X-Ayaya-Module-Key
      X-Ayaya-User-Email
      X-Ayaya-User-Display-Name
      X-Ayaya-User-Role
      X-Ayaya-Request-Id
    ].freeze

    before_action :force_non_navigational_format, prepend: true
    before_action :authenticate_user!

    def show
      module_key = extract_module_key(request.headers["X-Original-URI"].to_s)
      return head :forbidden if module_key.blank?

      registered_module = RegisteredModule.find_by(module_key:)
      return head :forbidden unless registered_module
      return head :service_unavailable unless %w[healthy degraded].include?(registered_module.runtime_status)
      return head :forbidden unless registered_module.accessible_by?(current_user)

      identity_headers = {
        "X-Ayaya-User-Id" => current_user.id.to_s,
        "X-Ayaya-User-Email" => current_user.email,
        "X-Ayaya-User-Display-Name" => current_user.display_name,
        "X-Ayaya-User-Role" => current_user.role,
        "X-Ayaya-Module-Key" => registered_module.module_key,
        "X-Ayaya-Request-Id" => request.request_id
      }
      return head :service_unavailable if registered_module.module_key == "telegram" && telegram_trusted_identity_secret.blank?

      identity_headers.each { |header, value| response.headers[header] = value }
      response.headers["X-Ayaya-Identity-Signature"] = telegram_identity_signature(identity_headers) if registered_module.module_key == "telegram"
      head :no_content
    end

    private

    def force_non_navigational_format
      request.format = :json
    end

    def extract_module_key(original_uri)
      match = original_uri.match(%r{\A/m/([a-z][a-z0-9_]*[a-z0-9])(?:/|\z)})
      match && match[1]
    end

    def telegram_identity_signature(headers)
      OpenSSL::HMAC.hexdigest("SHA256", telegram_trusted_identity_secret, TELEGRAM_IDENTITY_FIELDS.map { |field| headers[field].to_s }.join("\n"))
    end

    def telegram_trusted_identity_secret
      ENV["TELEGRAM_TRUSTED_IDENTITY_SECRET"].presence
    end
  end
end
