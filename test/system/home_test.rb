require "application_system_test_case"

class HomeTest < ApplicationSystemTestCase
  test "user signs in and sees available modules" do
    User.create!(email: "user@example.test", password: "password123", role: "user")
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

    visit root_path

    fill_in "Email", with: "user@example.test"
    fill_in "Password", with: "password123"
    click_button "Log in"

    assert_text "Ayaya"
    assert_link "Notes", href: "/m/notes"
    assert_text "Personal notes"
  end
end
