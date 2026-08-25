module Telegram
  class SafeRegex
    TIMEOUT = 0.01

    def self.match?(pattern, text)
      Regexp.new(pattern.to_s, Regexp::IGNORECASE, timeout: TIMEOUT).match?(text.to_s)
    rescue RegexpError
      false
    end

    def self.valid?(pattern)
      Regexp.new(pattern.to_s, Regexp::IGNORECASE, timeout: TIMEOUT)
      true
    rescue RegexpError
      false
    end
  end
end
