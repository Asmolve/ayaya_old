require "net/http"

module Telegram
  # Application-facing MTProto client. Telegram session material stays inside the
  # private transport that issued it; the app stores only its encrypted opaque handle.
  class MtprotoClient
    def self.from_environment(account:, http: Net::HTTP)
      endpoint = ENV["TELEGRAM_MTPROTO_CLIENT_URL"].presence
      raise ClientNotConfigured, "TELEGRAM_MTPROTO_CLIENT_URL is not configured" unless endpoint

      transport = OpaqueHandleTransport.new(endpoint:, token: ENV["TELEGRAM_MTPROTO_CLIENT_TOKEN"], http:)
      transport.live!
      transport.ready!
      new(account:, transport:)
    end

    def initialize(account:, transport: nil, endpoint: nil, token: nil, http: Net::HTTP, key_provider: KeyProvider.from_environment)
      @account = account
      @key_provider = key_provider
      @transport = transport || OpaqueHandleTransport.new(endpoint:, token:, http:)
    end

    def import_state(cursor: nil)
      response = request("imports", { cursor: cursor }, requires_handle: true)
      { "state" => JsonBoundary.normalize(response.fetch("state")), "cursor" => response["cursor"], "complete" => response["complete"] == true }
    end
    def read_state = request("state", {}, requires_handle: true)
    def apply(plan:, confirmed:) = request("operations/apply", { plan: plan, confirmed: confirmed }, requires_handle: true)
    def revoke_session(confirmed:) = request("auth/revoke", { confirmed: confirmed }, requires_handle: true)
    def start_phone(phone:, api_id:, api_hash:) = request("auth/phone", { phone: phone, api_id: api_id, api_hash: api_hash })
    def submit_code(challenge_id:, code:) = request("auth/code", { challenge_id: challenge_id, code: code })
    def submit_password(challenge_id:, password:) = request("auth/password", { challenge_id: challenge_id, password: password })
    def start_qr = request("auth/qr", {})
    def poll_qr(challenge_id:) = request("auth/qr/poll", { challenge_id: challenge_id })

    private

    def request(path, payload, requires_handle: false)
      account_id = @account&.telegram_account_id
      raise ClientNotConfigured, "Telegram account is required for private transport" if account_id.blank?

      handle = opaque_session_handle
      raise ClientNotConfigured, "MTProto session handle is not configured" if requires_handle && handle.blank?

      response = @transport.request(path:, payload: payload.merge(account_id:, session_handle: handle).merge(api_credentials).compact)
      authentication_response(path, response)
    end

    def opaque_session_handle
      envelope = @account&.encrypted_session
      return if envelope.blank?

      handle = EncryptedSecret.decrypt(envelope, key_provider: @key_provider)
      raise ClientNotConfigured, "stored MTProto credential is not an opaque session handle" unless OpaqueHandleTransport.opaque_handle?(handle)

      handle
    end

    def api_credentials
      return {} unless @account&.encrypted_api_credentials

      JSON.parse(EncryptedSecret.decrypt(@account.encrypted_api_credentials, key_provider: @key_provider))
    rescue JSON::ParserError
      raise ClientNotConfigured, "stored Telegram API credentials are invalid"
    end

    def authentication_response(path, response)
      response = JsonBoundary.normalize(response)
      raise ClientResponseError, "MTProto transport returned a session" if response.key?("session")
      return response unless path.start_with?("auth/") && response["state"] == "authenticated"

      handle = response.delete("session_handle")
      unless OpaqueHandleTransport.opaque_handle?(handle)
        raise ClientResponseError, "MTProto transport returned an invalid session handle"
      end

      response.merge("session" => handle)
    end
  end
end
