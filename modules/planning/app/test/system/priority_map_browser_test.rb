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

  test "places a successful move at the normalized server position" do
    third = PlanItem.create!(plan: @plan, title: "Third", priority: "next", position: 0)
    visit_as_ayaya_user "/m/planning?plan_id=#{@plan.id}"
    page.execute_script(<<~JAVASCRIPT)
      window.fetch = () => Promise.resolve(new Response(JSON.stringify({ priority: "next", position: 0 }), {
        status: 200,
        headers: { "Content-Type": "application/json" }
      }))
    JAVASCRIPT

    find("select[aria-label='Move First to a lane']").select("Next")

    assert_text "Moved First to Next."
    assert_equal [ @first.id, third.id ], page.all("[data-priority-lane='next'] [data-priority-item]").map { |node| node["data-item-id"].to_i }
  end

  test "associates every priority select with a unique explicit label" do
    visit_as_ayaya_user "/m/planning?plan_id=#{@plan.id}"

    select = find("select[aria-label='Move First to a lane']")
    assert_equal "plan-item-#{@first.id}-priority", select[:id]
    assert_selector "label[for='plan-item-#{@first.id}-priority']", text: "Move First to a lane"
    assert_priority_select_labels_are_unique

    find("button", text: "Second").click
    assert_equal "selected-plan-item-#{@second.id}-priority", find("[data-inspector-priority]")[:id]
    assert_priority_select_labels_are_unique
  end

  test "shows an insertion cue and persists a drop move" do
    visit_as_ayaya_user "/m/planning?plan_id=#{@plan.id}"

    drag_to_lane(@first, "next")

    assert_selector "[data-priority-lane='next'] [data-priority-items].is-insertion-target"
    drop_in_lane(@first, "next")
    assert_text "Moved First to Next."
    assert_equal "next", @first.reload.priority
  end

  test "announces a rollback when a priority move request fails" do
    visit_as_ayaya_user "/m/planning?plan_id=#{@plan.id}"
    page.execute_script("window.fetch = () => Promise.resolve(new Response('', { status: 422 }))")

    find("select[aria-label='Move First to a lane']").select("Next")

    assert_text "Could not move First. Changes were reverted."
    assert_selector "[data-priority-lane='now']", text: "First"
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

  private

  def drag_to_lane(item, priority)
    page.execute_script(<<~JAVASCRIPT, find("[data-item-id='#{item.id}']"), find("[data-priority-lane='#{priority}'] [data-priority-items]"))
      const transfer = new DataTransfer()
      transfer.setData("text/plain", arguments[0].dataset.itemId)
      arguments[0].dispatchEvent(new DragEvent("dragstart", { bubbles: true, dataTransfer: transfer }))
      arguments[1].dispatchEvent(new DragEvent("dragover", { bubbles: true, cancelable: true, dataTransfer: transfer }))
    JAVASCRIPT
  end

  def drop_in_lane(item, priority)
    page.execute_script(<<~JAVASCRIPT, find("[data-item-id='#{item.id}']"), find("[data-priority-lane='#{priority}'] [data-priority-items]"))
      const transfer = new DataTransfer()
      transfer.setData("text/plain", arguments[0].dataset.itemId)
      arguments[1].dispatchEvent(new DragEvent("drop", { bubbles: true, cancelable: true, dataTransfer: transfer }))
    JAVASCRIPT
  end

  def assert_priority_select_labels_are_unique
    ids = all("select").map { |select| select[:id] }.compact

    assert_equal ids.uniq, ids
    ids.each { |id| assert_selector "label[for='#{id}']" }
  end
end
