require "test_helper"

class AyayaIdentityTest < ActionDispatch::IntegrationTest
  test "rejects missing platform user header" do
    get "/m/planning"

    assert_response :unauthorized
  end

  test "rejects an identity for another module" do
    get "/m/planning", headers: ayaya_headers(module_key: "notes")

    assert_response :unauthorized
  end

  test "creates and refreshes the local user from trusted headers" do
    get "/m/planning", headers: ayaya_headers(email: "planner@example.test", display_name: "Planner")

    assert_response :success
    user = LocalUser.find_by!(core_user_id: "1")
    assert_equal "planner@example.test", user.email
    assert_equal "Planner", user.display_name
    assert_equal "user", user.global_role
    assert_not_nil user.last_seen_at
  end

  private

  def ayaya_headers(module_key: "planning", email: "user@example.test", display_name: "User")
    {
      "X-Ayaya-User-Id" => "1",
      "X-Ayaya-User-Email" => email,
      "X-Ayaya-User-Display-Name" => display_name,
      "X-Ayaya-User-Role" => "user",
      "X-Ayaya-Module-Key" => module_key
    }
  end
end
