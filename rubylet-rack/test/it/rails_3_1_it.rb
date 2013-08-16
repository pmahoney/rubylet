# Integration test with Rails 3.1

require 'it_helper'

class Rails_3_1_It < Minitest::Test
  include Rubylet::IntegrationTestCase
  self.app_root = File.expand_path('../examples/rails-3.1', __FILE__)
end
