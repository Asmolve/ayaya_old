module Modules
  class RefreshManifest
    Result = Struct.new(:success?, :registered_module, :errors, keyword_init: true)

    def self.call(registered_module:, adapter_secret:, client: nil)
      new(registered_module:, adapter_secret:, client:).call
    end

    def initialize(registered_module:, adapter_secret:, client: nil)
      @registered_module = registered_module
      @client = client || AdapterProtocol::Client.new(adapter_url: registered_module.adapter_url, adapter_secret:)
    end

    def call
      manifest = client.manifest
      validation = AdapterProtocol::ManifestValidator.call(manifest)
      return Result.new(success?: false, registered_module:, errors: validation.errors) unless validation.valid?

      registered_module.update!(
        name: manifest.dig("identity", "name"),
        version: manifest.dig("identity", "version"),
        adapter_protocol_version: manifest.dig("protocol", "adapter_protocol_version"),
        manifest_snapshot: manifest,
        last_manifest_refreshed_at: Time.current
      )

      Result.new(success?: true, registered_module:, errors: [])
    rescue AdapterProtocol::Client::Error, ActiveRecord::RecordInvalid => e
      Result.new(success?: false, registered_module:, errors: [e.message])
    end

    private

    attr_reader :registered_module, :client
  end
end
