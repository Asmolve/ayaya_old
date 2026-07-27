require "test_helper"

class RegisteredModuleTest < ActiveSupport::TestCase
  def build_module(attrs = {})
    RegisteredModule.new({
      module_key: "notes",
      name: "Notes",
      version: "0.1.0",
      adapter_url: "http://notes_adapter:8080",
      adapter_secret_digest: "digest",
      adapter_protocol_version: "1.0",
      admin_state: "enabled",
      runtime_status: "healthy",
      access_policy_mode: "authenticated",
      manifest_snapshot: {},
      status_snapshot: {}
    }.merge(attrs))
  end

  test "validates snake_case module key" do
    assert build_module(module_key: "shopping_list").valid?
    assert_not build_module(module_key: "shopping-list").valid?
    assert_not build_module(module_key: "ShoppingList").valid?
  end

  test "requires enabled admin state and healthy or degraded runtime status for user access" do
    user = User.create!(email: "user@example.test", password: "password123", role: "user")

    assert build_module(runtime_status: "healthy").accessible_by?(user)
    assert build_module(runtime_status: "degraded").accessible_by?(user)
    assert_not build_module(runtime_status: "unhealthy").accessible_by?(user)
    assert_not build_module(admin_state: "maintenance").accessible_by?(user)
  end

  test "admins access enabled modules regardless of manual allowlist" do
    admin = User.create!(email: "admin@example.test", password: "password123", role: "admin")
    mod = build_module(access_policy_mode: "manual")

    assert mod.accessible_by?(admin)
  end

  test "inactive users cannot access an enabled module" do
    user = User.create!(email: "inactive@example.test", password: "password123", role: "user", active: false)

    assert_not build_module.accessible_by?(user)
  end

  test "admin_only modules reject regular users and allow admins" do
    user = User.create!(email: "user@example.test", password: "password123", role: "user")
    admin = User.create!(email: "admin@example.test", password: "password123", role: "admin")
    mod = build_module(access_policy_mode: "admin_only")

    assert_not mod.accessible_by?(user)
    assert mod.accessible_by?(admin)
  end

  test "manual modules require an allowlist grant for regular users" do
    user = User.create!(email: "user@example.test", password: "password123", role: "user")
    mod = build_module(access_policy_mode: "manual")

    assert_not mod.accessible_by?(user)
    mod.save!
    mod.module_user_accesses.create!(user: user)
    assert mod.accessible_by?(user)
  end
end
