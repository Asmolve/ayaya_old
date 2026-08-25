require "json"
require "net/http"
require "uri"

module Telegram
  # HTTP contract for an operator-provisioned private MTProto owner. This is a
  # transport boundary only; it deliberately does not emulate Telegram or hold
  # a Telegram session. The only credential it accepts from the Rails app is a
  # versioned, non-reversible session handle issued by that owner.
  class OpaqueHandleTransport
    CONTRACT = "opaque-session-handle.v1"
    INTERNAL_HOST = "telegram_mtproto"
    INTERNAL_PORT = 8081

    def self.opaque_handle?(value)
      value.is_a?(String) && value.match?(%r{\Aopaque-session-handle-v1:[A-Za-z0-9_-]{32,}\z})
    end

    def initialize(endpoint:, token:, http: Net::HTTP, production: Rails.env.production?)
      @endpoint = URI(endpoint)
      @token = token
      @http = http
      validate_endpoint!(production:)
      raise ClientNotConfigured, "MTProto transport token is not configured" if production && @token.blank?
    rescue URI::InvalidURIError
      raise ClientNotConfigured, "MTProto transport endpoint is invalid"
    end

    def ready!
      response = get("health/ready")
      unless response == { "status" => "ok", "ready" => true, "contract" => CONTRACT }
        raise ClientNotConfigured, "MTProto transport readiness contract is invalid"
      end

      true
    end

    def live!
      raise ClientNotConfigured, "MTProto transport liveness contract is invalid" unless get("health/live") == { "status" => "ok" }

      true
    end

    def request(path:, payload:)
      post(path, payload)
    end

    private

    def validate_endpoint!(production:)
      return unless production

      internal_http = @endpoint.scheme == "http" && @endpoint.host == INTERNAL_HOST && @endpoint.port == INTERNAL_PORT
      return if @endpoint.scheme == "https" || internal_http

      raise ClientNotConfigured, "production MTProto endpoint must use HTTPS or the dedicated private transport"
    end

    def get(path)
      exchange(Net::HTTP::Get.new(uri_for(path)))
    end

    def post(path, payload)
      request = Net::HTTP::Post.new(uri_for(path))
      request["Content-Type"] = "application/json"
      request.body = JSON.generate(JsonBoundary.normalize(payload))
      exchange(request)
    end

    def exchange(request)
      request["Authorization"] = "Bearer #{@token}" if @token.present?
      response = @http.start(@endpoint.host, @endpoint.port, use_ssl: @endpoint.scheme == "https", open_timeout: 5, read_timeout: 20) { |http| http.request(request) }
      payload = parse_json_object(response.body)
      flood_wait = FloodWait.from_response(status: response.code, payload: payload)
      raise flood_wait if flood_wait
      raise ClientResponseError, "MTProto transport request failed" unless response.code.to_i.between?(200, 299)

      payload
    rescue Timeout::Error, Errno::ECONNREFUSED, SocketError, IOError, SystemCallError
      raise OutcomeUnknown, "MTProto transport outcome is unknown"
    end

    def parse_json_object(body)
      parsed = JSON.parse(body)
      raise ClientResponseError, "MTProto transport response was not a JSON object" unless parsed.is_a?(Hash)

      JsonBoundary.normalize(parsed)
    rescue JSON::ParserError
      raise ClientResponseError, "MTProto transport response was not valid JSON"
    end

    def uri_for(path)
      @endpoint.dup.tap { |uri| uri.path = [ @endpoint.path.delete_suffix("/"), path ].join("/") }
    end
  end
end
