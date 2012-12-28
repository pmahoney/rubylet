# Integration test with Sinatra 1.3

require 'it_helper'

class Sinatra_1_3_It < MiniTest::Unit::TestCase
  include Rubylet::IntegrationTestCase
  self.app_root = File.expand_path('../examples/sinatra-1.3', __FILE__)
end
