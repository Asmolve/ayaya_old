require "digest"
require "json"

module Telegram
  class CanonicalSnapshot
    VERSION = 2
    attr_reader :payload, :source_hash

    def self.build(**attributes)
      new(attributes)
    end

    def initialize(attributes)
      attributes = attributes.deep_stringify_keys
      @set_like_paths = Array(attributes.delete("canonical_set_paths")).map { |path| Array(path).map(&:to_s) }
      @payload = normalize(attributes).merge("canonical_version" => VERSION)
      @source_hash = Digest::SHA256.hexdigest(JSON.generate(@payload))
    end

    private

    def normalize(value, path = [])
      case value
      when Hash then value.to_h.stringify_keys.sort.to_h { |key, nested| [ key, normalize(nested, path + [ key ]) ] }
      when Array
        normalized = value.map { |item| normalize(item, path + [ "[]" ]) }
        set_like_path?(path) ? normalized.sort_by { |item| JSON.generate(item) } : normalized
      else value
      end
    end

    def set_like_path?(path)
      @set_like_paths.include?(path)
    end
  end
end
