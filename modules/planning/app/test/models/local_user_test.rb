require "test_helper"

class LocalUserTest < ActiveSupport::TestCase
  test "requires a unique core user id" do
    LocalUser.create!(core_user_id: "one")
    duplicate = LocalUser.new(core_user_id: "one")

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:core_user_id], "has already been taken"
  end
end
