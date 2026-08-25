require "test_helper"
require "nokogiri"

class LayoutRegressionTest < ActionDispatch::IntegrationTest
  test "the ActiveAdmin page serves the custom dashboard stylesheet" do
    admin = User.create!(email: "admin@example.test", password: "password123", role: "admin")
    sign_in admin

    get admin_root_path

    stylesheet = Nokogiri::HTML(response.body).at_css("link[href*='active_admin']")
    assert_not_nil stylesheet

    stylesheet_path = stylesheet["href"]
    get stylesheet_path

    assert_response :success
    assert_includes response.body, "body.active_admin { background: #f4f6f2; color: #26302d; }"
    assert_includes response.body, ".dashboard-summary .column { border: 0; border-left: 1px solid #e4e8e4; padding-left: 1.25rem; }"
  end

  test "a guest Devise page hides authenticated navigation and account controls" do
    get new_user_session_path

    assert_response :success
    assert_select ".platform-nav", count: 0
    assert_select ".platform-account", count: 0
    assert_select "form[action='#{destroy_user_session_path}']", count: 0
  end
end
