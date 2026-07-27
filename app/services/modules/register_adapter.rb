require "digest"

module Modules
  class RegisterAdapter
    Result = Struct.new(:success?, :registered_module, :errors, keyword_init: true)

    def self.call(adapter_url:, adapter_secret:, client: nil)
      new(adapter_url:, adapter_secret:, client:).call
    end

    def initialize(adapter_url:, adapter_secret:, client: nil)
      @adapter_url = adapter_url
      @adapter_secret = adapter_secret
      @client = client || AdapterProtocol::Client.new(adapter_url:, adapter_secret:)
    end

    def call
      manifest = client.manifest
      validation = AdapterProtocol::ManifestValidator.call(manifest)
      return Result.new(success?: false, errors: validation.errors) unless validation.valid?

      identity = manifest.fetch("identity")
      protocol = manifest.fetch("protocol")
      access = manifest.fetch("access")

      registered_module = RegisteredModule.new(
        module_key: identity.fetch("module_key"),
        name: identity.fetch("name"),
        version: identity.fetch("version"),
        adapter_url: adapter_url,
        adapter_secret_digest: digest_secret(adapter_secret),
        adapter_protocol_version: protocol.fetch("adapter_protocol_version"),
        admin_state: "registered",
        runtime_status: "unknown",
        access_policy_mode: access.fetch("default_policy"),
        manifest_snapshot: manifest,
        status_snapshot: {},
        last_manifest_refreshed_at: Time.current
      )

      if registered_module.save
        Result.new(success?: true, registered_module:, errors: [])
      else
        Result.new(success?: false, registered_module:, errors: registered_module.errors.full_messages)
      end
    rescue AdapterProtocol::Client::Error => e
      Result.new(success?: false, errors: [ e.message ])
    end

    private

    attr_reader :adapter_url, :adapter_secret, :client

    def digest_secret(secret)
      Digest::SHA256.hexdigest(secret)
    end
  end
end
