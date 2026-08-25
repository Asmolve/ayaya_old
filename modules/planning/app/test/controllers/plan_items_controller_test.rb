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
    assert_equal [ plan.id, "now", 0 ], [ item.plan_id, item.priority, item.position ]
    assert_redirected_to "/m/planning?plan_id=#{plan.id}"
  end

  test "appends a new item in its owner plan lane regardless of a submitted position" do
    owner = LocalUser.create!(core_user_id: "1")
    plan = Plan.create!(local_user: owner, title: "Launch")
    other_plan = Plan.create!(local_user: owner, title: "Private backlog")
    first = PlanItem.create!(plan: plan, title: "First", priority: "now", position: 0)
    PlanItem.create!(plan: other_plan, title: "Elsewhere", priority: "now", position: 0)

    post "/m/planning/plan_items", params: {
      plan_item: { plan_id: plan.id, title: "Submitted first", priority: "now", position: 0 }
    }, headers: ayaya_headers

    assert_redirected_to "/m/planning?plan_id=#{plan.id}"
    assert_equal [ [ first.id, 0 ], [ PlanItem.last.id, 1 ] ], plan.plan_items.now.order(:position).pluck(:id, :position)
  end

  test "normalizes a lane after deletion before appending a new item" do
    owner = LocalUser.create!(core_user_id: "1")
    plan = Plan.create!(local_user: owner, title: "Launch")
    first = PlanItem.create!(plan: plan, title: "First", priority: "now", position: 0)
    deleted = PlanItem.create!(plan: plan, title: "Deleted", priority: "now", position: 1)
    last = PlanItem.create!(plan: plan, title: "Last", priority: "now", position: 2)

    delete "/m/planning/plan_items/#{deleted.id}", headers: ayaya_headers
    post "/m/planning/plan_items", params: {
      plan_item: { plan_id: plan.id, title: "Appended", priority: "now" }
    }, headers: ayaya_headers

    assert_redirected_to "/m/planning?plan_id=#{plan.id}"
    assert_equal [ [ first.id, 0 ], [ last.id, 1 ], [ PlanItem.last.id, 2 ] ],
      plan.plan_items.now.order(:position, :id).pluck(:id, :position)
  end

  test "advertises only usable plan item read routes" do
    owner = LocalUser.create!(core_user_id: "1")
    plan = Plan.create!(local_user: owner, title: "Launch")
    item = PlanItem.create!(plan: plan, title: "Write brief")

    get "/m/planning/plan_items/#{item.id}", headers: ayaya_headers
    assert_redirected_to "/m/planning?plan_id=#{plan.id}"

    get "/m/planning/plan_items/#{item.id}/edit", headers: ayaya_headers
    assert_response :success

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("/m/planning/plan_items", method: :get)
    end
    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("/m/planning/plan_items/new", method: :get)
    end
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

  test "moves an item through the JSON position endpoint and normalizes both lanes" do
    owner = LocalUser.create!(core_user_id: "1")
    plan = Plan.create!(local_user: owner, title: "Launch")
    first = PlanItem.create!(plan: plan, title: "First", priority: "now", position: 0)
    moved = PlanItem.create!(plan: plan, title: "Move me", priority: "now", position: 1)
    next_item = PlanItem.create!(plan: plan, title: "Already next", priority: "next", position: 4)

    patch "/m/planning/plan_items/#{moved.id}/position",
      params: { priority: "next", position: 0 },
      as: :json,
      headers: ayaya_headers

    assert_response :success
    assert_equal [ moved.id, "next", 0 ], JSON.parse(response.body).values_at("id", "priority", "position")
    assert_equal [ [ first.id, 0 ] ], plan.plan_items.now.order(:position).pluck(:id, :position)
    assert_equal [ [ moved.id, 0 ], [ next_item.id, 1 ] ], plan.plan_items.next.order(:position).pluck(:id, :position)
  end

  test "uses stored lane positions for consecutive moves without reordering untouched items" do
    owner = LocalUser.create!(core_user_id: "1")
    plan = Plan.create!(local_user: owner, title: "Launch")
    first = PlanItem.create!(plan: plan, title: "First", priority: "now", position: 2)
    second = PlanItem.create!(plan: plan, title: "Second", priority: "now", position: 0)
    third = PlanItem.create!(plan: plan, title: "Third", priority: "now", position: 1)

    patch "/m/planning/plan_items/#{second.id}/position",
      params: { priority: "now", position: 1 },
      as: :json,
      headers: ayaya_headers

    assert_response :success
    assert_equal [ third.id, second.id, first.id ], plan.plan_items.now.order(:position, :id).pluck(:id)

    patch "/m/planning/plan_items/#{second.id}/position",
      params: { priority: "now", position: 2 },
      as: :json,
      headers: ayaya_headers

    assert_response :success
    assert_equal [ third.id, first.id, second.id ], plan.plan_items.now.order(:position, :id).pluck(:id)
  end

  test "returns JSON validation errors and scopes position moves to the current user" do
    owner = LocalUser.create!(core_user_id: "1")
    plan = Plan.create!(local_user: owner, title: "Launch")
    item = PlanItem.create!(plan: plan, title: "First")
    other = LocalUser.create!(core_user_id: "2")
    private_item = PlanItem.create!(plan: Plan.create!(local_user: other, title: "Private"), title: "Nope")

    patch "/m/planning/plan_items/#{item.id}/position",
      params: { priority: "urgent", position: -1 },
      as: :json,
      headers: ayaya_headers

    assert_response :unprocessable_entity
    assert_equal [ "Priority is invalid", "Position must be a non-negative integer" ], JSON.parse(response.body).fetch("errors")

    patch "/m/planning/plan_items/#{private_item.id}/position",
      params: { priority: "now", position: 0 },
      as: :json,
      headers: ayaya_headers

    assert_response :not_found
    assert_equal({ "error" => "not_found" }, JSON.parse(response.body))
  end

  test "requires both priority and position for a JSON position move" do
    owner = LocalUser.create!(core_user_id: "1")
    item = PlanItem.create!(plan: Plan.create!(local_user: owner, title: "Launch"), title: "First")

    [ {}, { priority: "now" }, { position: 0 } ].each do |payload|
      patch "/m/planning/plan_items/#{item.id}/position", params: payload, as: :json, headers: ayaya_headers

      assert_response :unprocessable_entity
    end
  end

  test "does not reorder an item when normal update validation fails" do
    owner = LocalUser.create!(core_user_id: "1")
    plan = Plan.create!(local_user: owner, title: "Launch")
    item = PlanItem.create!(plan: plan, title: "First", priority: "now", position: 0)
    next_item = PlanItem.create!(plan: plan, title: "Next", priority: "next", position: 0)

    patch "/m/planning/plan_items/#{item.id}",
      params: { plan_item: { title: "", priority: "next", position: 0 } },
      headers: ayaya_headers

    assert_response :unprocessable_entity
    assert_equal [ "now", 0 ], item.reload.attributes.values_at("priority", "position")
    assert_equal [ "next", 0 ], next_item.reload.attributes.values_at("priority", "position")
  end

  test "HTML move controls reorder an item without JavaScript" do
    owner = LocalUser.create!(core_user_id: "1")
    plan = Plan.create!(local_user: owner, title: "Launch")
    first = PlanItem.create!(plan: plan, title: "First", priority: "now", position: 0)
    second = PlanItem.create!(plan: plan, title: "Second", priority: "now", position: 1)

    patch "/m/planning/plan_items/#{second.id}",
      params: { plan_item: { priority: "now", position: 0 } },
      headers: ayaya_headers

    assert_redirected_to "/m/planning?plan_id=#{plan.id}"
    assert_equal [ [ second.id, 0 ], [ first.id, 1 ] ], plan.plan_items.now.order(:position).pluck(:id, :position)
  end

  test "HTML move controls render validation errors for an invalid position payload" do
    owner = LocalUser.create!(core_user_id: "1")
    item = PlanItem.create!(plan: Plan.create!(local_user: owner, title: "Launch"), title: "First")

    patch "/m/planning/plan_items/#{item.id}",
      params: { plan_item: { priority: "urgent", position: -1 } },
      headers: ayaya_headers

    assert_response :unprocessable_entity
    assert_select ".planning-errors", /Priority is invalid/
  end

  private

  def ayaya_headers
    { "X-Ayaya-User-Id" => "1", "X-Ayaya-Module-Key" => "planning" }
  end
end
