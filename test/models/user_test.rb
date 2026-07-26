require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "defaults display name from email" do
    user = User.new(email: "alice@example.test", password: "password123", role: "user")

    assert user.valid?
    assert_equal "alice", user.display_name
  end

  test "rejects unknown role" do
    user = User.new(email: "alice@example.test", password: "password123", role: "owner")

    assert_not user.valid?
    assert_includes user.errors[:role], "is not included in the list"
  end

  test "inactive users cannot authenticate" do
    user = User.new(email: "alice@example.test", password: "password123", role: "user", active: false)

    assert_not user.active_for_authentication?
  end
end
