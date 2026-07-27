module AyayaContract
  class Runner
    Result = Struct.new(:success?, :errors, keyword_init: true)

    CRITICAL_FIELDS = [
      %w[identity module_key],
      %w[identity name],
      %w[identity version],
      %w[protocol adapter_protocol_version],
      %w[protocol capabilities],
      %w[routes],
      %w[access default_policy]
    ].freeze

    def initialize(package_manifest:, runtime_manifest:)
      @package_manifest = package_manifest
      @runtime_manifest = runtime_manifest
      @errors = []
    end

    def call
      validate_manifest("package", package_manifest)
      validate_manifest("runtime", runtime_manifest)
      compare_critical_fields
      Result.new(success?: errors.empty?, errors:)
    end

    private

    attr_reader :package_manifest, :runtime_manifest, :errors

    def validate_manifest(label, manifest)
      result = AdapterProtocol::ManifestValidator.call(manifest)
      result.errors.each { |error| errors << "#{label}: #{error}" }
    end

    def compare_critical_fields
      CRITICAL_FIELDS.each do |path|
        package_value = safely_dig(package_manifest, path)
        runtime_value = safely_dig(runtime_manifest, path)
        errors << "critical field mismatch: #{path.join(".")}" unless package_value == runtime_value
      end
    end

    def safely_dig(value, path)
      path.reduce(value) do |current, key|
        current.is_a?(Hash) ? current[key] : nil
      end
    end
  end
end
