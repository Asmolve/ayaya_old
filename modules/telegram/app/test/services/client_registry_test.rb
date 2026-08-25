require "test_helper"

class ClientRegistryTest < ActiveSupport::TestCase
  setup { Telegram::ClientRegistry.reset! }
  teardown { Telegram::ClientRegistry.reset! }

  test "fails closed when no production MTProto transport is configured" do
    assert_raises(Telegram::ClientNotConfigured) { Telegram::ClientRegistry.client_for(nil) }
  end

  test "uses TestClient only when it is injected" do
    client = Telegram::TestClient.new

    Telegram::ClientRegistry.with(client) do
      assert_same client, Telegram::ClientRegistry.client_for(nil)
    end
  end
end
