require "application_system_test_case"

class PriorityMapBrowserTest < ApplicationSystemTestCase
  setup do
    owner = LocalUser.create!(core_user_id: "1")
    @plan = Plan.create!(local_user: owner, title: "Browser coverage")
    @first = PlanItem.create!(plan: @plan, title: "First", priority: "now", position: 0)
    @second = PlanItem.create!(plan: @plan, title: "Second", priority: "now", position: 1)
  end

  test "uses JavaScript to move an item and announces the result" do
    visit_as_ayaya_user "/m/planning?plan_id=#{@plan.id}"

    find("select[aria-label='Move Second to a lane']").select("Next")

    assert_text "Moved Second to Next."
    assert_selector "[data-priority-lane='next']", text: "Second"
  end

  test "keyboard activation uses the move controls" do
    visit_as_ayaya_user "/m/planning?plan_id=#{@plan.id}"

    find("button[aria-label='Move Second up']").send_keys(:enter)

    assert_text "Moved Second to Now."
    assert_equal [ @second.id, @first.id ], @plan.plan_items.now.order(:position).pluck(:id)
  end

  test "keeps lanes and inspector usable at a narrow viewport" do
    page.current_window.resize_to(390, 844)
    visit_as_ayaya_user "/m/planning?plan_id=#{@plan.id}"

    assert_selector "aside[data-item-inspector]"
    assert_equal 1, page.evaluate_script("getComputedStyle(document.querySelector('.priority-lanes')).gridTemplateColumns").split.length
  end
end
