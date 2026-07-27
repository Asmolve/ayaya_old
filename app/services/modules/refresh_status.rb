module Modules
  class RefreshStatus
    Result = Struct.new(:success?, :registered_module, :errors, keyword_init: true)

    VALID_STATUSES = %w[healthy degraded unhealthy unreachable incompatible].freeze

    def self.call(registered_module:, adapter_secret:, client: nil)
      new(registered_module:, adapter_secret:, client:).call
    end

    def initialize(registered_module:, adapter_secret:, client: nil)
      @registered_module = registered_module
      @client = client || AdapterProtocol::Client.new(adapter_url: registered_module.adapter_url, adapter_secret:)
    end

    def call
      status = client.status
      unless status.is_a?(Hash)
        return fail_with_status("incompatible", "adapter status response must be a JSON object")
      end

      runtime_status = status.fetch("runtime_status", "unhealthy")
      runtime_status = "unhealthy" unless VALID_STATUSES.include?(runtime_status)

      registered_module.update!(
        runtime_status: runtime_status,
        status_snapshot: status,
        last_status_refreshed_at: Time.current
      )

      Result.new(success?: true, registered_module:, errors: [])
    rescue AdapterProtocol::Client::Unavailable => e
      fail_with_status("unreachable", e.message)
    rescue AdapterProtocol::Client::Unauthorized, AdapterProtocol::Client::InvalidResponse => e
      fail_with_status("incompatible", e.message)
    rescue AdapterProtocol::Client::Error, ActiveRecord::RecordInvalid => e
      fail_with_status("unhealthy", e.message)
    end

    private

    attr_reader :registered_module, :client

    def fail_with_status(runtime_status, error)
      registered_module.update!(
        runtime_status:,
        status_snapshot: { "error" => error },
        last_status_refreshed_at: Time.current
      )
      Result.new(success?: false, registered_module:, errors: [error])
    end
  end
end
