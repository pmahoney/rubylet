# Integration test with Sinatra 1.3

require 'it_helper'

class Sinatra_1_3_It < MiniTest::Unit::TestCase
  include Rubylet::IntegrationTestCase
  self.app_root = File.expand_path('../examples/sinatra-1.3', __FILE__)

  # this assumes the server sends asynchronously even while it
  # synchronously waits for the whole response; lame
  def test_stream
    resp = get('tests/stream')
    assert_equal 200, resp.code.to_i
    assert_equal "It's gonna be legen - (wait for it) - dary!", resp.body
  end

  def test_stream_keep_open
    resp = get('tests/stream_keep_open')
    assert_equal 200, resp.code.to_i
    assert_equal "It's gonna be legen - (wait for it) - dary!", resp.body
  end
end
