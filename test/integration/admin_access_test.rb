require "test_helper"

class AdminAccessTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  test "signed-in non-admin cannot access ActiveAdmin" do
    user = User.create!(email: "user@example.test", password: "password123", role: "user")
    sign_in user

    get admin_root_path

    assert_response :not_found
  end

  test "inactive user cannot establish a Devise session" do
    user = User.create!(email: "inactive@example.test", password: "password123", role: "user", active: false)

    post user_session_path, params: { user: { email: user.email, password: "password123" } }

    assert_redirected_to new_user_session_path
    get admin_root_path
    assert_redirected_to new_user_session_path
  end

  test "admins cannot delete users through ActiveAdmin" do
    admin = User.create!(email: "admin@example.test", password: "password123", role: "admin")
    target = User.create!(email: "target@example.test", password: "password123", role: "user")
    sign_in admin

    delete admin_user_path(target)

    assert_response :not_found
    assert User.exists?(target.id)
  end

  test "ActiveAdmin does not configure destructive batch actions" do
    ActiveAdmin.application.load!

    resource = ActiveAdmin.application.namespaces[:admin].resources[User]

    assert_empty resource.batch_actions
  end
end
