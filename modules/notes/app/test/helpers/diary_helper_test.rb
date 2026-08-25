require "test_helper"

class DiaryHelperTest < ActionView::TestCase
  include DiaryHelper

  test "normalizes a date to its quarter start" do
    assert_equal Date.new(2026, 7, 1), quarter_start(Date.new(2026, 9, 10))
    assert_equal Date.new(2026, 10, 1), quarter_start(Date.new(2026, 12, 31))
  end

  test "normalizes week and month selections inclusively" do
    assert_equal Date.new(2026, 9, 7)..Date.new(2026, 9, 13), range_for_iso_week(Date.new(2026, 9, 10))
    assert_equal Date.new(2026, 9, 1)..Date.new(2026, 9, 30), range_for_month(Date.new(2026, 9, 10))
  end
end
