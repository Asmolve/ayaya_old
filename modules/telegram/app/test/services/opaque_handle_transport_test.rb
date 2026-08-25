require "test_helper"
require "net/http"

class OpaqueHandleTransportTest < ActiveSupport::TestCase
  OPAQUE_HANDLE = "opaque-session-handle-v1:8YVWZYlObsaHHjcQIrpCBYXZgzx0R0Bq"

  test "sends only an encrypted-account opaque handle and preserves import pagination" do
    account = TelegramAccount.create!(module_user: ModuleUser.create!(core_user_id: "opaque-client"), telegram_account_id: "account")
    account.update!(encrypted_session: Telegram::EncryptedSecret.encrypt(OPAQUE_HANDLE, key_provider: Telegram::KeyProvider.from_environment))
    http = RecordingHttp.new(body: '{"state":{"dialogs":[]},"cursor":"next-page","complete":false}')
    client = Telegram::MtprotoClient.new(endpoint: "http://telegram_mtproto:8081/private", account: account, http: http)

    response = client.import_state(cursor: "first-page")
    payload = JSON.parse(http.requests.fetch(0).body)

    assert_equal "account", payload.fetch("account_id")
    assert_equal OPAQUE_HANDLE, payload.fetch("session_handle")
    assert_equal "first-page", payload.fetch("cursor")
    refute payload.key?("session")
    assert_equal "next-page", response.fetch("cursor")
    assert_equal false, response.fetch("complete")
  end

  test "passes decrypted API credentials only to the private transport" do
    account = TelegramAccount.create!(module_user: ModuleUser.create!(core_user_id: "opaque-api-creds"), telegram_account_id: "account")
    account.update!(
      encrypted_session: Telegram::EncryptedSecret.encrypt(OPAQUE_HANDLE, key_provider: Telegram::KeyProvider.from_environment),
      encrypted_api_credentials: Telegram::EncryptedSecret.encrypt(JSON.generate({ "api_id" => 123, "api_hash" => "private-hash" }), key_provider: Telegram::KeyProvider.from_environment)
    )
    http = RecordingHttp.new(body: '{"state":{"dialogs":[]},"complete":true}')

    Telegram::MtprotoClient.new(endpoint: "http://telegram_mtproto:8081", account: account, http: http).import_state

    payload = JSON.parse(http.requests.fetch(0).body)
    assert_equal 123, payload.fetch("api_id")
    assert_equal "private-hash", payload.fetch("api_hash")
  end

  test "maps only a versioned opaque handle from an authenticated transport response" do
    account = TelegramAccount.create!(module_user: ModuleUser.create!(core_user_id: "opaque-auth"), telegram_account_id: "pending")
    http = RecordingHttp.new(body: %({"state":"authenticated","session_handle":"#{OPAQUE_HANDLE}","telegram_account_id":"account"}))
    client = Telegram::MtprotoClient.new(endpoint: "http://telegram_mtproto:8081", account: account, http: http)

    result = client.submit_code(challenge_id: "challenge", code: "12345")

    assert_equal OPAQUE_HANDLE, result.fetch("session")
    refute result.key?("session_handle")
    refute JSON.parse(http.requests.fetch(0).body).key?("session")
  end

  test "rejects a legacy plaintext session before it crosses the transport boundary" do
    account = TelegramAccount.create!(module_user: ModuleUser.create!(core_user_id: "legacy-session"), telegram_account_id: "account")
    account.update!(encrypted_session: Telegram::EncryptedSecret.encrypt("plaintext-telegram-session", key_provider: Telegram::KeyProvider.from_environment))
    http = RecordingHttp.new(body: '{"state":{"dialogs":[]},"complete":true}')
    client = Telegram::MtprotoClient.new(endpoint: "http://telegram_mtproto:8081", account: account, http: http)

    assert_raises(Telegram::ClientNotConfigured) { client.import_state }
    assert_empty http.requests
  end

  test "fails closed when the readiness contract is malformed" do
    transport = Telegram::OpaqueHandleTransport.new(endpoint: "http://telegram_mtproto:8081", token: "private-token", http: RecordingHttp.new(body: '{"status":"ok","ready":true}'))

    assert_raises(Telegram::ClientNotConfigured) { transport.ready! }
  end

  test "authenticates readiness and accepts the opaque-handle contract" do
    http = RecordingHttp.new(body: '{"status":"ok","ready":true,"contract":"opaque-session-handle.v1"}')
    transport = Telegram::OpaqueHandleTransport.new(endpoint: "http://telegram_mtproto:8081/private", token: "private-token", http: http)

    assert transport.ready!
    assert_equal "/private/health/ready", http.requests.fetch(0).path
    assert_equal "Bearer private-token", http.requests.fetch(0)["Authorization"]
  end

  test "requires the health liveness JSON contract" do
    http = RecordingHttp.new(body: '{"status":"ok"}')
    transport = Telegram::OpaqueHandleTransport.new(endpoint: "http://telegram_mtproto:8081/private", token: "private-token", http: http)

    assert transport.live!
    assert_equal "/private/health/live", http.requests.fetch(0).path
  end

  test "environment-backed clients verify authenticated liveness and readiness before use" do
    account = TelegramAccount.create!(module_user: ModuleUser.create!(core_user_id: "opaque-environment"), telegram_account_id: "pending")
    http = RecordingHttp.new(bodies: [ '{"status":"ok"}', '{"status":"ok","ready":true,"contract":"opaque-session-handle.v1"}' ])
    previous_url = ENV["TELEGRAM_MTPROTO_CLIENT_URL"]
    previous_token = ENV["TELEGRAM_MTPROTO_CLIENT_TOKEN"]
    ENV["TELEGRAM_MTPROTO_CLIENT_URL"] = "http://telegram_mtproto:8081/private"
    ENV["TELEGRAM_MTPROTO_CLIENT_TOKEN"] = "private-token"

    client = Telegram::MtprotoClient.from_environment(account: account, http: http)

    assert_instance_of Telegram::MtprotoClient, client
    assert_equal [ "/private/health/live", "/private/health/ready" ], http.requests.map(&:path)
  ensure
    ENV["TELEGRAM_MTPROTO_CLIENT_URL"] = previous_url
    ENV["TELEGRAM_MTPROTO_CLIENT_TOKEN"] = previous_token
  end

  test "maps injected transport timeouts to a non-sensitive unknown outcome" do
    http = RecordingHttp.new(error: Timeout::Error.new("private host:8081 timed out"))
    account = TelegramAccount.create!(module_user: ModuleUser.create!(core_user_id: "opaque-timeout"), telegram_account_id: "pending")
    client = Telegram::MtprotoClient.new(endpoint: "http://telegram_mtproto:8081", account: account, http: http)

    error = assert_raises(Telegram::OutcomeUnknown) { client.start_qr }

    assert_equal "MTProto transport outcome is unknown", error.message
  end

  test "maps a structured FLOOD_WAIT 429 response to a bounded retry pause" do
    http = RecordingHttp.new(body: '{"error":"FLOOD_WAIT_7200"}', status: "429")
    account = TelegramAccount.create!(module_user: ModuleUser.create!(core_user_id: "opaque-flood-wait"), telegram_account_id: "pending")
    client = Telegram::MtprotoClient.new(endpoint: "http://telegram_mtproto:8081", account: account, http: http)

    error = assert_raises(Telegram::FloodWait) { client.start_qr }

    assert_equal 3600, error.wait_seconds
    assert_equal "Telegram rate limit; retry later", error.message
  end

  test "production requires a bearer credential and a private endpoint" do
    assert_raises(Telegram::ClientNotConfigured) do
      Telegram::OpaqueHandleTransport.new(endpoint: "http://untrusted.example:8081", token: "private-token", production: true)
    end
    assert_raises(Telegram::ClientNotConfigured) do
      Telegram::OpaqueHandleTransport.new(endpoint: "http://telegram_mtproto:8081", token: nil, production: true)
    end
  end

  private

  class RecordingHttp
    attr_reader :requests

    def initialize(body: nil, bodies: nil, error: nil, status: "200")
      @body = body
      @bodies = bodies
      @error = error
      @status = status
      @requests = []
    end

    def start(*)
      yield self
    end

    def request(request)
      @requests << request
      raise @error if @error

      Response.new(@bodies&.shift || @body, @status)
    end

    class Response < Net::HTTPOK
      def initialize(body, status)
        super("1.1", status, "OK")
        @payload = body
      end

      def body = @payload
    end
  end
end
