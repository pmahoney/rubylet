# Integration test with plain Rack 1.4

require 'it_helper'

class Rack_1_4_It < MiniTest::Unit::TestCase
  include Rubylet::IntegrationTestCase
  self.app_root = File.expand_path('../examples/rack-1.4', __FILE__)

  def test_delayed
    resp = get('tests/delayed')
    assert_equal 200, resp.code.to_i
    assert_equal "delayed!", resp.body
  end

  # this assumes the server sends asynchronously even while it
  # synchronously waits for the whole response; lame
  def test_stream
    resp = get('tests/stream')
    assert_equal 200, resp.code.to_i
    assert_equal 'Hello, World', resp.body
  end
end
