module Telegram
  class AuthenticationFlow
    STATES = %w[disconnected awaiting_code awaiting_password awaiting_qr authenticated].freeze

    def initialize(account:, client:, key_provider: KeyProvider.from_environment)
      @account = account
      @client = client
      @key_provider = key_provider
    end

    def start_phone(phone:, api_id:, api_hash:)
      result = @client.start_phone(phone: phone, api_id: api_id, api_hash: api_hash).deep_stringify_keys
      result["api_credentials"] ||= { "api_id" => api_id, "api_hash" => api_hash }
      transition_from!(%w[disconnected], result)
    end

    def submit_code(code:)
      transition_from!(%w[awaiting_code], @client.submit_code(challenge_id: challenge_id!, code: code))
    end

    def submit_password(password:)
      transition_from!(%w[awaiting_password], @client.submit_password(challenge_id: challenge_id!, password: password))
    end

    def start_qr
      transition_from!(%w[disconnected], @client.start_qr)
    end

    def poll_qr
      transition_from!(%w[awaiting_qr], @client.poll_qr(challenge_id: challenge_id!))
    end

    private

    def transition_from!(allowed, result)
      @account.reload
      raise ArgumentError, "invalid authentication transition" unless allowed.include?(@account.connection_state)

      result = result.deep_stringify_keys
      state = result.fetch("state")
      raise ArgumentError, "unknown authentication state" unless STATES.include?(state)
      if result["qr_data_uri"].present? && !result["qr_data_uri"].match?(%r{\Adata:image/png;base64,[A-Za-z0-9+/=]+\z})
        raise ArgumentError, "QR image must be a PNG data URI"
      end

      attributes = {
        connection_state: state,
        auth_challenge: result.slice("challenge_id", "qr_data_uri", "expires_at"),
        read_only: state != "authenticated"
      }
      if result["api_credentials"]
        attributes[:encrypted_api_credentials] = EncryptedSecret.encrypt(JSON.generate(result.fetch("api_credentials")), key_provider: @key_provider)
      end
      if state == "authenticated"
        attributes[:encrypted_session] = EncryptedSecret.encrypt(result.fetch("session"), key_provider: @key_provider)
        attributes[:telegram_account_id] = result.fetch("telegram_account_id")
        attributes[:display_name] = result["display_name"]
        attributes[:auth_challenge] = {}
        attributes[:disconnected_at] = nil
      end
      @account.update!(attributes.compact)
      @account
    end

    def challenge_id!
      @account.auth_challenge.fetch("challenge_id")
    end
  end
end
