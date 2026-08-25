require "test_helper"

class DynamicLimitsTest < ActiveSupport::TestCase
  test "uses a documented conservative fallback and blocks writes for unknown entitlement" do
    limits = Telegram::DynamicLimits.from_app_config({})

    assert_equal 10, limits.folder_limit
    assert_equal 100, limits.chats_per_folder_limit
    assert_predicate limits, :writes_blocked?
  end

  test "uses supplied entitlement limits before applying a plan" do
    limits = Telegram::DynamicLimits.from_app_config(
      "dialog_filters_limit_default" => 20,
      "dialog_filters_chats_limit_default" => 200,
      "dialogs_folder_pinned_limit_default" => 5,
      "dialog_filters_title_length_limit_default" => 12
    )

    assert_equal 20, limits.folder_limit
    assert_equal 200, limits.chats_per_folder_limit
    refute_predicate limits, :writes_blocked?
  end
end
