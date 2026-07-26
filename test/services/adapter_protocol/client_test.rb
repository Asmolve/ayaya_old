require "test_helper"
require "webmock/minitest"

class AdapterProtocol::ClientTest < ActiveSupport::TestCase
  test "fetches manifest with bearer secret" do
    stub_request(:get, "http://notes_adapter:8080/ayaya/manifest")
      .with(headers: { "Authorization" => "Bearer secret" })
      .to_return(status: 200, body: { identity: { module_key: "notes" } }.to_json, headers: { "Content-Type" => "application/json" })

    client = AdapterProtocol::Client.new(adapter_url: "http://notes_adapter:8080", adapter_secret: "secret")

    assert_equal "notes", client.manifest.dig("identity", "module_key")
  end

  test "raises unavailable on connection failure" do
    stub_request(:get, "http://notes_adapter:8080/ayaya/status").to_timeout
    client = AdapterProtocol::Client.new(adapter_url: "http://notes_adapter:8080", adapter_secret: "secret")

    assert_raises(AdapterProtocol::Client::Unavailable) { client.status }
  end

  test "raises unauthorized on 401" do
    stub_request(:get, "http://notes_adapter:8080/ayaya/manifest").to_return(status: 401)
    client = AdapterProtocol::Client.new(adapter_url: "http://notes_adapter:8080", adapter_secret: "secret")

    assert_raises(AdapterProtocol::Client::Unauthorized) { client.manifest }
  end
end
