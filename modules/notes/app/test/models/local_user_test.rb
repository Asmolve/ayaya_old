require "test_helper"

class LocalUserTest < ActiveSupport::TestCase
  test "requires unique core user id" do
    LocalUser.create!(core_user_id: "1", email: "one@example.test")
    duplicate = LocalUser.new(core_user_id: "1", email: "two@example.test")

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:core_user_id], "has already been taken"
  end
end
