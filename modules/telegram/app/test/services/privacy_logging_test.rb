require "test_helper"

class PrivacyLoggingTest < ActiveSupport::TestCase
  test "filters credentials and message content from structured logs" do
    filter = ActiveSupport::ParameterFilter.new(Rails.application.config.filter_parameters)
    filtered = filter.filter(phone: "+79990000000", api_hash: "api-hash", session: "session-data", message: "private text")

    assert_equal "[FILTERED]", filtered[:phone]
    assert_equal "[FILTERED]", filtered[:api_hash]
    assert_equal "[FILTERED]", filtered[:session]
    assert_equal "[FILTERED]", filtered[:message]
  end
end
