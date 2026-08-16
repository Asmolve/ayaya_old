module Modules
  class LocalRegistration
    Configuration = Data.define(:module_key, :display_name, :adapter_url_env, :adapter_secret_env)

    CONFIGURATIONS = {
      "pic_obtainer" => Configuration.new(
        module_key: "pic_obtainer".freeze,
        display_name: "Pic Obtainer".freeze,
        adapter_url_env: "PIC_OBTAINER_ADAPTER_URL".freeze,
        adapter_secret_env: "PIC_OBTAINER_AYAYA_ADAPTER_SECRET".freeze
      )
    }.freeze

    def self.configuration(key)
      CONFIGURATIONS.fetch(key.to_s)
    end

    def self.call(key, client: nil)
      new(key, client:).call
    end

    def initialize(key, client: nil)
      @key = key
      @client = client
    end

    def call
      config = configuration
      existing = RegisteredModule.find_by(module_key: config.module_key)
      return result(success?: true, registered_module: existing, errors: []) if existing

      adapter_url = ENV[config.adapter_url_env].presence
      adapter_secret = ENV[config.adapter_secret_env].presence
      return result(success?: false, errors: [ "Local adapter URL is not configured." ]) if adapter_url.blank? || adapter_secret.blank?

      registration = RegisterAdapter.call(adapter_url:, adapter_secret:, client:)
      return registration if registration.success?

      result(
        success?: false,
        registered_module: registration.registered_module,
        errors: registration.errors.map { |error| error.to_s.gsub(adapter_secret, "[FILTERED]") }
      )
    rescue KeyError
      result(success?: false, errors: [ "Unknown local module registration." ])
    rescue AdapterProtocol::Client::Error, SocketError, SystemCallError, Timeout::Error, Net::OpenTimeout, Net::ReadTimeout
      result(success?: false, errors: [ "Local adapter registration failed." ])
    end

    private

    attr_reader :key, :client

    def configuration
      self.class.configuration(key)
    end

    def result(**attributes)
      RegisterAdapter::Result.new(**attributes)
    end
  end
end
