require_relative "boot"

require "rails"
require "active_model/railtie"
require "active_job/railtie"
require "active_record/railtie"
require "action_controller/railtie"
require "action_mailer/railtie"
require "action_view/railtie"
require "rails/test_unit/railtie"

Bundler.require(*Rails.groups)

module Planning
  class Application < Rails::Application
    config.load_defaults 8.1
    config.assets.prefix = "/m/planning/assets"
    config.autoload_lib(ignore: %w[assets tasks])
    config.generators.system_tests = nil
  end
end
