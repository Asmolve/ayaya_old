require "test_helper"

class PlanTest < ActiveSupport::TestCase
  test "requires an owner and a title" do
    plan = Plan.new

    assert_not plan.valid?
    assert_includes plan.errors[:local_user], "must exist"
    assert_includes plan.errors[:title], "can't be blank"
  end
end
