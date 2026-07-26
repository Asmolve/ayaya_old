module AdapterProtocol
  class ManifestValidator
    Result = Struct.new(:valid?, :errors, keyword_init: true)

    REQUIRED_CAPABILITIES = %w[manifest.v1 health.v1 status.v1].freeze
    SUPPORTED_PROTOCOL_MAJOR = "1"
    MODULE_KEY_PATTERN = /\A[a-z][a-z0-9_]*[a-z0-9]\z/
    ACCESS_POLICIES = %w[authenticated admin_only manual].freeze

    def self.call(manifest)
      new(manifest).call
    end

    def initialize(manifest)
      @manifest = manifest || {}
      @errors = []
    end

    def call
      validate_identity
      validate_protocol
      validate_routes
      validate_access
      Result.new(valid?: errors.empty?, errors: errors)
    end

    private

    attr_reader :manifest, :errors

    def validate_identity
      identity = section("identity")
      add("identity.module_key is required") if identity["module_key"].blank?
      add("identity.name is required") if identity["name"].blank?
      add("identity.version is required") if identity["version"].blank?
      add("identity.module_key must be snake_case") if identity["module_key"].present? && !identity["module_key"].match?(MODULE_KEY_PATTERN)
    end

    def validate_protocol
      protocol = section("protocol")
      version = protocol["adapter_protocol_version"].to_s
      capabilities = Array(protocol["capabilities"])

      add("protocol.adapter_protocol_version is required") if version.blank?
      add("protocol.adapter_protocol_version major version is unsupported") if version.present? && version.split(".").first != SUPPORTED_PROTOCOL_MAJOR

      REQUIRED_CAPABILITIES.each do |capability|
        add("protocol.capabilities must include #{capability}") unless capabilities.include?(capability)
      end
    end

    def validate_routes
      identity = section("identity")
      routes = section("routes")
      module_key = identity["module_key"].to_s
      expected_ui = "/m/#{module_key}"
      expected_api = "/m/#{module_key}/api"

      add("routes.ui_base_path is required") if routes["ui_base_path"].blank?
      add("routes.api_base_path is required") if routes["api_base_path"].blank?
      add("routes.ui_base_path must equal #{expected_ui}") if module_key.present? && routes["ui_base_path"].present? && routes["ui_base_path"] != expected_ui
      add("routes.api_base_path must equal #{expected_api}") if module_key.present? && routes["api_base_path"].present? && routes["api_base_path"] != expected_api
    end

    def validate_access
      access = section("access")
      policy = access["default_policy"].to_s

      add("access.default_policy is required") if policy.blank?
      add("access.default_policy is unsupported") if policy.present? && !ACCESS_POLICIES.include?(policy)
    end

    def section(name)
      value = manifest[name]
      value.is_a?(Hash) ? value : {}
    end

    def add(message)
      errors << message
    end
  end
end
