require File.expand_path('../boot', __FILE__)

# not rails/all to avoid active_record
require 'action_controller/railtie'
require 'action_mailer/railtie'
require 'active_resource/railtie'

Bundler.require(:default, Rails.env) if defined?(Bundler)

module TestApp
  class Application < Rails::Application
    config.encoding = "utf-8"
  end
end
