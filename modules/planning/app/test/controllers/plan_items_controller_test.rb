require "test_helper"

class PlanItemsControllerTest < ActionDispatch::IntegrationTest
  test "creates an item in the current user's plan" do
    owner = LocalUser.create!(core_user_id: "1")
    plan = Plan.create!(local_user: owner, title: "Launch")

    assert_difference("PlanItem.count", 1) do
      post "/m/planning/plan_items", params: {
        plan_item: { plan_id: plan.id, title: "Write brief", priority: "now", position: 2 }
      }, headers: ayaya_headers
    end

    item = PlanItem.last
    assert_equal [ plan.id, "now", 2 ], [ item.plan_id, item.priority, item.position ]
    assert_redirected_to "/m/planning?plan_id=#{plan.id}"
  end

  test "renders errors for a blank title and invalid priority" do
    owner = LocalUser.create!(core_user_id: "1")
    plan = Plan.create!(local_user: owner, title: "Launch")

    post "/m/planning/plan_items", params: {
      plan_item: { plan_id: plan.id, title: "", priority: "urgent" }
    }, headers: ayaya_headers

    assert_response :unprocessable_entity
    assert_select ".planning-errors", /Title can't be blank/
    assert_select ".planning-errors", /Priority is not included in the list/
  end

  test "updates completion and destroys the current user's item" do
    owner = LocalUser.create!(core_user_id: "1")
    plan = Plan.create!(local_user: owner, title: "Launch")
    item = PlanItem.create!(plan: plan, title: "Write brief")

    patch "/m/planning/plan_items/#{item.id}", params: { plan_item: { completed: true } }, headers: ayaya_headers

    assert_redirected_to "/m/planning?plan_id=#{plan.id}"
    assert_predicate item.reload, :completed?

    assert_difference("PlanItem.count", -1) do
      delete "/m/planning/plan_items/#{item.id}", headers: ayaya_headers
    end
    assert_redirected_to "/m/planning?plan_id=#{plan.id}"
  end

  test "returns not found for another user's plan or item" do
    other = LocalUser.create!(core_user_id: "2")
    plan = Plan.create!(local_user: other, title: "Private")
    item = PlanItem.create!(plan: plan, title: "Private item")

    post "/m/planning/plan_items", params: { plan_item: { plan_id: plan.id, title: "Nope" } }, headers: ayaya_headers
    assert_response :not_found

    patch "/m/planning/plan_items/#{item.id}", params: { plan_item: { title: "Nope" } }, headers: ayaya_headers
    assert_response :not_found
  end

  private

  def ayaya_headers
    { "X-Ayaya-User-Id" => "1", "X-Ayaya-Module-Key" => "planning" }
  end
end
