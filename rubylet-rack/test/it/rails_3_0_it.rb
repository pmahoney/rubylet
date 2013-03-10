# Integration test with Rails 3.0

require 'it_helper'

class Rails_3_0_It < MiniTest::Unit::TestCase
  include Rubylet::IntegrationTestCase
  self.app_root = File.expand_path('../examples/rails-3.0', __FILE__)
end
