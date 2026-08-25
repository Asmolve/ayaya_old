module Telegram
  class StaticKeyProvider
    def initialize(key_id, key)
      @key_id = key_id
      @key = key
    end

    def current = [ @key_id, @key ]
    def fetch(key_id) = key_id == @key_id ? @key : nil
  end
end
