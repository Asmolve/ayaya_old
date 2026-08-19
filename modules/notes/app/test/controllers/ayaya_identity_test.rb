require "test_helper"

class AyayaIdentityTest < ActionDispatch::IntegrationTest
  test "rejects missing platform user header" do
    get "/m/notes"

    assert_response :unauthorized
  end

  test "rejects wrong module key" do
    get "/m/notes", headers: {
      "X-Ayaya-User-Id" => "1",
      "X-Ayaya-Module-Key" => "wrong"
    }

    assert_response :unauthorized
  end

  test "creates and refreshes local user from trusted headers" do
    local_user = nil
    first_seen_at = nil

    freeze_time do
      get "/m/notes", headers: {
        "X-Ayaya-User-Id" => "1",
        "X-Ayaya-User-Email" => "user@example.test",
        "X-Ayaya-User-Display-Name" => "User",
        "X-Ayaya-User-Role" => "user",
        "X-Ayaya-Module-Key" => "notes"
      }

      assert_response :success
      assert_includes response.body, "No notes yet"
      assert_includes response.body, "New note"
      local_user = LocalUser.find_by!(core_user_id: "1")
      assert_equal "user@example.test", local_user.email
      assert_equal "User", local_user.display_name
      assert_equal "user", local_user.global_role
      assert_equal Time.current.to_i, local_user.last_seen_at.to_i
      first_seen_at = local_user.last_seen_at
    end

    travel 1.second do
      get "/m/notes", headers: {
        "X-Ayaya-User-Id" => "1",
        "X-Ayaya-User-Email" => "updated@example.test",
        "X-Ayaya-User-Display-Name" => "Updated User",
        "X-Ayaya-User-Role" => "admin",
        "X-Ayaya-Module-Key" => "notes"
      }
    end

    assert_response :success
    assert_includes response.body, "No notes yet"
    assert_includes response.body, "New note"
    local_user.reload
    assert_equal "updated@example.test", local_user.email
    assert_equal "Updated User", local_user.display_name
    assert_equal "admin", local_user.global_role
    assert_operator local_user.last_seen_at, :>, first_seen_at
  end
end
