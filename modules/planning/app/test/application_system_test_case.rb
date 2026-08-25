require "test_helper"
require "capybara/rails"
require "capybara/minitest"

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  driven_by :selenium, using: :headless_chrome, screen_size: [ 1400, 1400 ] do |options|
    options.add_argument("--no-sandbox")
    options.add_argument("--disable-dev-shm-usage")
  end

  private

  def visit_as_ayaya_user(path, core_user_id: "1")
    ENV["AYAYA_SYSTEM_TEST_USER_ID"] = core_user_id
    visit path
  end
end

Capybara.app = lambda do |env|
  env["HTTP_X_AYAYA_USER_ID"] = ENV.fetch("AYAYA_SYSTEM_TEST_USER_ID", "1")
  env["HTTP_X_AYAYA_MODULE_KEY"] = "planning"
  Rails.application.call(env)
end
