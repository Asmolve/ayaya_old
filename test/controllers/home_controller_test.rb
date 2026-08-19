require "test_helper"

class HomeControllerTest < ActionDispatch::IntegrationTest
  test "requires authentication" do
    get "/"

    assert_redirected_to new_user_session_path
  end

  test "lists accessible enabled modules" do
    user = User.create!(email: "user@example.test", password: "password123", role: "user")
    sign_in user
    RegisteredModule.create!(
      module_key: "notes",
      name: "Notes",
      version: "0.1.0",
      adapter_url: "http://notes_adapter:8080",
      adapter_secret_digest: "digest",
      adapter_protocol_version: "1.0",
      admin_state: "enabled",
      runtime_status: "healthy",
      access_policy_mode: "authenticated",
      manifest_snapshot: { "presentation" => { "description" => "Personal notes" } },
      status_snapshot: {}
    )

    get "/"

    assert_response :success
    assert_select "a[href='/m/notes']", text: "Open Notes"
    assert_includes response.body, "Personal notes"
  end
end
