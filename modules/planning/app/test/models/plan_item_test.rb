require "test_helper"

class PlanItemTest < ActiveSupport::TestCase
  test "defaults to next priority and incomplete" do
    user = LocalUser.create!(core_user_id: "owner")
    plan = Plan.create!(local_user: user, title: "Launch")
    item = PlanItem.new(plan: plan, title: "Write brief")

    assert_predicate item, :next?
    assert_not item.completed?
  end

  test "requires a plan and title" do
    item = PlanItem.new

    assert_not item.valid?
    assert_includes item.errors[:plan], "must exist"
    assert_includes item.errors[:title], "can't be blank"
  end

  test "rejects a priority outside the priority map lanes" do
    user = LocalUser.create!(core_user_id: "owner")
    plan = Plan.create!(local_user: user, title: "Launch")
    item = PlanItem.new(plan: plan, title: "Write brief", priority: "urgent")

    assert_not item.valid?
    assert_includes item.errors[:priority], "is not included in the list"
  end
end
