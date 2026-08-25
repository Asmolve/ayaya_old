module Telegram
  class TestClient
    attr_reader :mutations, :revocations

    def initialize(remote_state: { "folders" => [], "dialogs" => [], "app_config" => {} }, fault: nil, faults: nil, auth_result: nil)
      @remote_state = remote_state.deep_stringify_keys
      @faults = Array(faults || fault)
      @auth_result = auth_result
      @mutations = []
      @revocations = 0
    end

    def import_state(cursor: nil)
      { state: @remote_state.deep_dup, cursor: cursor, complete: true }
    end

    def read_state
      @remote_state.deep_dup
    end

    def apply(plan:, confirmed:)
      raise ReadOnlyViolation unless confirmed
      fault = @faults.shift
      raise DispatchNotStarted if fault == :timeout_before_dispatch
      raise FloodWait.new(60) if fault == :flood_wait

      @mutations << plan.deep_dup
      @remote_state = plan.fetch("expected_postcondition", @remote_state).deep_stringify_keys
      raise OutcomeUnknown if fault == :timeout_after_dispatch

      :confirmed
    end

    def start_phone(api_id:, api_hash:, **)
      @mutations << { "auth" => "start_phone" }
      (@auth_result || { "state" => "awaiting_code", "challenge_id" => "test-challenge" }).merge("api_credentials" => { "api_id" => api_id, "api_hash" => api_hash })
    end

    def submit_code(**)
      @mutations << { "auth" => "submit_code" }
      @auth_result || { "state" => "authenticated", "session" => "test-session", "telegram_account_id" => "test-account" }
    end

    def submit_password(**)
      @mutations << { "auth" => "submit_password" }
      @auth_result || { "state" => "authenticated", "session" => "test-session", "telegram_account_id" => "test-account" }
    end

    def start_qr
      @mutations << { "auth" => "start_qr" }
      @auth_result || { "state" => "awaiting_qr", "challenge_id" => "test-qr", "qr_data_uri" => "data:image/png;base64,dGVzdA==" }
    end

    def poll_qr(**)
      @mutations << { "auth" => "poll_qr" }
      @auth_result || { "state" => "awaiting_qr" }
    end

    def revoke_session(confirmed:)
      raise ReadOnlyViolation unless confirmed

      @revocations += 1
      @mutations << { "revoke_session" => true }
    end
  end
end
