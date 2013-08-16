# Integration test with Rails 3.2

require 'it_helper'

class Rails_3_2_It < Minitest::Test
  include Rubylet::IntegrationTestCase
  self.app_root = File.expand_path('../examples/rails-3.2', __FILE__)
end
