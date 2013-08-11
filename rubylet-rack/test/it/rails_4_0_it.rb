# Integration test with Rails 4.0

require 'it_helper'

class Rails_4_0_It < MiniTest::Unit::TestCase
  include Rubylet::IntegrationTestCase
  self.app_root = File.expand_path('../examples/rails-4.0', __FILE__)
end
