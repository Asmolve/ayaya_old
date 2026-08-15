require "application_system_test_case"

class PicObtainerModuleSystemTest < ApplicationSystemTestCase
  test "admin sees the enabled Pic Obtainer module" do
    User.create!(email: "pic-system-admin@example.test", password: "password123", role: "admin")
    RegisteredModule.create!(
      module_key: "pic_obtainer",
      name: "Pic Obtainer",
      version: "0.1.0",
      adapter_url: "http://pic_obtainer_api:8000",
      adapter_secret_digest: "digest",
      adapter_protocol_version: "1.0",
      admin_state: "enabled",
      runtime_status: "healthy",
      access_policy_mode: "admin_only",
      manifest_snapshot: { "presentation" => { "description" => "Media discovery" } },
      status_snapshot: {}
    )

    visit root_path
    fill_in "Email", with: "pic-system-admin@example.test"
    fill_in "Password", with: "password123"
    click_button "Log in"

    assert_link "Pic Obtainer", href: "/m/pic_obtainer"
    assert_text "Media discovery"
  end
end
