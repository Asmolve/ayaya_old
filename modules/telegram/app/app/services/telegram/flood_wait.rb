module Telegram
  class FloodWait < StandardError
    MINIMUM_SECONDS = 1
    MAXIMUM_SECONDS = 1.hour.to_i
    DEFAULT_SECONDS = 60

    attr_reader :wait_seconds

    def self.from_response(status:, payload:)
      body = payload.to_h.deep_stringify_keys
      error = body["error"]
      error_details = error.is_a?(Hash) ? error.deep_stringify_keys : {}
      messages = [ error, body["message"], body["description"], error_details["type"], error_details["message"] ].compact.map(&:to_s)
      flood_wait_seconds = messages.filter_map { |message| message[/FLOOD_WAIT_(\d+)/, 1] }.first
      retry_after = body["retry_after"] || body["wait_seconds"] || error_details["retry_after"] || error_details["wait_seconds"] || flood_wait_seconds
      return unless status.to_i == 429 || flood_wait_seconds.present?

      new(retry_after || DEFAULT_SECONDS)
    end

    def initialize(wait_seconds)
      @wait_seconds = Integer(wait_seconds).clamp(MINIMUM_SECONDS, MAXIMUM_SECONDS)
      super("Telegram rate limit; retry later")
    rescue ArgumentError, TypeError
      @wait_seconds = DEFAULT_SECONDS
      super("Telegram rate limit; retry later")
    end
  end
end
