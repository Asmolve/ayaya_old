module Telegram
  class ClientRegistry
    class << self
      def client_for(account)
        injected_client || MtprotoClient.from_environment(account: account)
      end

      def with(client)
        clients = Thread.current[:telegram_client_overrides] ||= []
        clients << client
        yield
      ensure
        clients&.pop
      end

      def use(client)
        @client = client
      end

      def reset!
        @client = nil
        Thread.current[:telegram_client_overrides] = []
      end

      private

      def injected_client
        Thread.current[:telegram_client_overrides].to_a.last || @client
      end
    end
  end
end
