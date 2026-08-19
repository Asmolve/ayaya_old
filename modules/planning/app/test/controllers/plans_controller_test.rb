require "test_helper"

class PlansControllerTest < ActionDispatch::IntegrationTest
  test "shows the workspace and only the current user's plan navigation" do
    owner = LocalUser.create!(core_user_id: "1")
    other = LocalUser.create!(core_user_id: "2")
    Plan.create!(local_user: owner, title: "My plan")
    Plan.create!(local_user: other, title: "Private plan")

    get "/m/planning", headers: ayaya_headers

    assert_response :success
    assert_includes response.body, "My plan"
    assert_not_includes response.body, "Private plan"
    assert_includes response.body, "Create plan"
  end

  test "creates a plan for the current user" do
    assert_difference("Plan.count", 1) do
      post "/m/planning/plans", params: { plan: { title: "Launch" } }, headers: ayaya_headers
    end

    assert_equal "1", Plan.last.local_user.core_user_id
    assert_redirected_to "/m/planning?plan_id=#{Plan.last.id}"
  end

  test "renders validation errors for an invalid plan" do
    post "/m/planning/plans", params: { plan: { title: "" } }, headers: ayaya_headers

    assert_response :unprocessable_entity
    assert_select ".planning-errors", /Title can't be blank/
  end

  test "updates and destroys only the current user's plan" do
    owner = LocalUser.create!(core_user_id: "1")
    plan = Plan.create!(local_user: owner, title: "Before")

    patch "/m/planning/plans/#{plan.id}", params: { plan: { title: "After" } }, headers: ayaya_headers

    assert_redirected_to "/m/planning?plan_id=#{plan.id}"
    assert_equal "After", plan.reload.title

    assert_difference("Plan.count", -1) do
      delete "/m/planning/plans/#{plan.id}", headers: ayaya_headers
    end
    assert_redirected_to "/m/planning"
  end

  test "returns not found for another user's plan" do
    other = LocalUser.create!(core_user_id: "2")
    plan = Plan.create!(local_user: other, title: "Private")

    patch "/m/planning/plans/#{plan.id}", params: { plan: { title: "Nope" } }, headers: ayaya_headers

    assert_response :not_found
    assert_equal "Private", plan.reload.title
  end

  private

  def ayaya_headers
    { "X-Ayaya-User-Id" => "1", "X-Ayaya-Module-Key" => "planning" }
  end
end
