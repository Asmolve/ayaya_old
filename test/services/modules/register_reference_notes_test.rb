require "test_helper"

class Modules::RegisterReferenceNotesTest < ActiveSupport::TestCase
  test "registers the reference adapter with environment configuration" do
    with_adapter_environment(url: "https://notes-adapter.example", secret: "configured-secret") do
      assert_equal "https://notes-adapter.example", Modules::RegisterReferenceNotes.adapter_url
      assert_equal "configured-secret", Modules::RegisterReferenceNotes.adapter_secret
    end
  end

  test "requires the adapter secret to be configured" do
    with_adapter_environment(url: "https://notes-adapter.example", secret: nil) do
      assert_raises KeyError do
        Modules::RegisterReferenceNotes.adapter_secret
      end
    end
  end

  private

  def with_adapter_environment(url:, secret:)
    previous_url = ENV["NOTES_ADAPTER_URL"]
    previous_secret = ENV["NOTES_ADAPTER_SECRET"]
    ENV["NOTES_ADAPTER_URL"] = url
    secret.nil? ? ENV.delete("NOTES_ADAPTER_SECRET") : ENV["NOTES_ADAPTER_SECRET"] = secret
    yield
  ensure
    ENV["NOTES_ADAPTER_URL"] = previous_url
    previous_secret.nil? ? ENV.delete("NOTES_ADAPTER_SECRET") : ENV["NOTES_ADAPTER_SECRET"] = previous_secret
  end
end
