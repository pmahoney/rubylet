# Integration test with Ramaze 2012.12

require 'it_helper'

class Ramaze_2012_12_It < Minitest::Test
  include Rubylet::IntegrationTestCase
  self.app_root = File.expand_path('../examples/ramaze-2012.12', __FILE__)
end
