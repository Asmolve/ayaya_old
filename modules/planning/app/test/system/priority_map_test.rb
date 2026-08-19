require "test_helper"

class PriorityMapTest < ActionDispatch::IntegrationTest
  test "creates, moves, reorders, and completes items from the priority map" do
    owner = LocalUser.create!(core_user_id: "1")
    plan = Plan.create!(local_user: owner, title: "Autumn release")
    first = PlanItem.create!(plan: plan, title: "Shape the brief", priority: "now", position: 0)
    second = PlanItem.create!(plan: plan, title: "Invite reviewers", priority: "now", position: 1)

    get "/m/planning", params: { plan_id: plan.id }, headers: ayaya_headers

    assert_response :success
    assert_select "[data-priority-map]"
    assert_select "#now-lane-title", "Now"
    assert_select "#next-lane-title", "Next"
    assert_select "#later-lane-title", "Later"
    assert_select "form[data-inline-add] input[name='plan_item[title]']"
    assert_select "aside[data-item-inspector]", /Selected item/
    assert_select "button[aria-label='Move Shape the brief up']"
    assert_select "button[aria-label='Move Invite reviewers down']"
    assert_select "select[aria-label='Move Shape the brief to a lane']"
    assert_select "select#plan-item-#{first.id}-priority"
    assert_select "label[for='plan-item-#{first.id}-priority']", "Move Shape the brief to a lane"
    assert_select "[data-priority-status][aria-live='polite']"
    assert_select ".drag-placement-hint", /Use Move up or down to place it precisely/

    assert_difference("PlanItem.count", 1) do
      post "/m/planning/plan_items", params: {
        plan_item: { plan_id: plan.id, title: "Publish the note", priority: "later", position: 0 }
      }, headers: ayaya_headers
    end

    patch "/m/planning/plan_items/#{second.id}", params: {
      plan_item: { priority: "next", position: 0 }
    }, headers: ayaya_headers
    assert_equal [ "next", 0 ], second.reload.attributes.values_at("priority", "position")

    patch "/m/planning/plan_items/#{first.id}", params: {
      plan_item: { position: 1, completed: true }
    }, headers: ayaya_headers
    assert_equal [ 0, true ], first.reload.attributes.values_at("position", "completed")
  end

  test "stacks the priority map at a narrow viewport and keeps inspector actions available" do
    stylesheet = File.read(Rails.root.join("app/assets/stylesheets/application.css"))
    owner = LocalUser.create!(core_user_id: "1")
    plan = Plan.create!(local_user: owner, title: "Small screen")
    PlanItem.create!(plan: plan, title: "One clear next step")

    get "/m/planning", params: { plan_id: plan.id }, headers: ayaya_headers

    assert_match(/@media \(max-width: 48rem\)/, stylesheet)
    assert_match(/\.priority-lanes\s*\{\s*grid-template-columns:\s*1fr/, stylesheet)
    assert_select "aside[data-item-inspector] form"
    assert_select "a", "Edit item"
  end

  test "uses a normal-text contrast color for the selected plan rail link" do
    stylesheet = File.read(Rails.root.join("app/assets/stylesheets/application.css"))

    assert_match(/\.plan-navigation a\[aria-current="page"\] \{ color: #6f4520;/, stylesheet)
  end

  private

  def ayaya_headers
    { "X-Ayaya-User-Id" => "1", "X-Ayaya-Module-Key" => "planning" }
  end
end
