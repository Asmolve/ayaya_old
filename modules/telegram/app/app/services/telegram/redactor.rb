module Telegram
  class Redactor
    SENSITIVE_KEYS = /phone|api[_-]?hash|api[_-]?id|code|password|session|credential|secret|token|message/i

    def self.call(value)
      case value
      when Hash
        value.each_with_object({}) do |(key, item), result|
          result[key.to_s] = key.to_s.match?(SENSITIVE_KEYS) ? "[REDACTED]" : call(item)
        end
      when Array then value.map { |item| call(item) }
      else value
      end
    end
  end
end
