require_relative "boot"

require "rails"
require "active_model/railtie"
require "active_job/railtie"
require "active_record/railtie"
require "action_controller/railtie"
require "action_cable/engine"
require "action_mailer/railtie"
require "action_view/railtie"
require "rails/test_unit/railtie"

Bundler.require(*Rails.groups)

module Telegram
  class Application < Rails::Application
    config.load_defaults 8.1
    config.assets.prefix = "/m/telegram/assets"
    config.autoload_lib(ignore: %w[assets tasks])
    config.generators.system_tests = nil
    config.filter_parameters += %i[phone api_hash api_id code password session credentials secret token message]
  end
end
