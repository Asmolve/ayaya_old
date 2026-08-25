module Telegram
  class JsonBoundary
    def self.normalize(value)
      normalized = value.deep_stringify_keys
      validate!(normalized)
      normalized
    rescue NoMethodError
      raise ClientResponseError, "MTProto payload must be a JSON object"
    end

    def self.validate!(value)
      case value
      when Hash then value.each_value { |nested| validate!(nested) }
      when Array then value.each { |nested| validate!(nested) }
      when String, Integer, Float, TrueClass, FalseClass, NilClass then nil
      else raise ClientResponseError, "MTProto payload contains a non-JSON value"
      end
    end
  end
end
