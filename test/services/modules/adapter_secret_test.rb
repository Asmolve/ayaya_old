require "test_helper"

class Modules::AdapterSecretTest < ActiveSupport::TestCase
  test "returns the configured Telegram Adapter secret for its registered URL" do
    registered_module = create_telegram_module(adapter_url: "http://telegram_adapter:8080")
    previous_secret = ENV["TELEGRAM_ADAPTER_SECRET"]
    previous_url = ENV["TELEGRAM_ADAPTER_URL"]
    ENV["TELEGRAM_ADAPTER_SECRET"] = "telegram-secret"
    ENV["TELEGRAM_ADAPTER_URL"] = "http://telegram_adapter:8080"

    assert_equal "telegram-secret", Modules::AdapterSecret.for(registered_module)
  ensure
    previous_secret.nil? ? ENV.delete("TELEGRAM_ADAPTER_SECRET") : ENV["TELEGRAM_ADAPTER_SECRET"] = previous_secret
    previous_url.nil? ? ENV.delete("TELEGRAM_ADAPTER_URL") : ENV["TELEGRAM_ADAPTER_URL"] = previous_url
  end

  test "does not return the Telegram Adapter secret for a different registered URL" do
    registered_module = create_telegram_module(adapter_url: "http://unexpected_adapter:8080")
    previous_secret = ENV["TELEGRAM_ADAPTER_SECRET"]
    previous_url = ENV["TELEGRAM_ADAPTER_URL"]
    ENV["TELEGRAM_ADAPTER_SECRET"] = "telegram-secret"
    ENV["TELEGRAM_ADAPTER_URL"] = "http://telegram_adapter:8080"

    assert_nil Modules::AdapterSecret.for(registered_module)
  ensure
    previous_secret.nil? ? ENV.delete("TELEGRAM_ADAPTER_SECRET") : ENV["TELEGRAM_ADAPTER_SECRET"] = previous_secret
    previous_url.nil? ? ENV.delete("TELEGRAM_ADAPTER_URL") : ENV["TELEGRAM_ADAPTER_URL"] = previous_url
  end

  private

  def create_telegram_module(adapter_url:)
    RegisteredModule.create!(
      module_key: "telegram",
      name: "Telegram Dialog Organizer",
      version: "0.1.0",
      adapter_url:,
      adapter_secret_digest: "digest",
      adapter_protocol_version: "1.0",
      admin_state: "registered",
      runtime_status: "healthy",
      access_policy_mode: "authenticated",
      manifest_snapshot: {},
      status_snapshot: {}
    )
  end
end
