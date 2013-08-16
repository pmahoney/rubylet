# Integration test with plain Rack 1.5.0

require 'it_helper'

require 'net/http'

class Rack_1_5_0_It < Minitest::Test
  include Rubylet::IntegrationTestCase
  self.app_root = File.expand_path('../examples/rack-1.5.0', __FILE__)

  def test_delayed
    resp = get('tests/delayed')
    assert_equal 200, resp.code.to_i
    assert_equal "delayed!", resp.body
  end

  # this assumes the server sends asynchronously even while it
  # synchronously waits for the whole response; lame
  # def test_stream
  #   resp = get('tests/stream')
  #   assert_equal 200, resp.code.to_i
  #   assert_equal 'Hello, World', resp.body
  # end

  def test_stream
    chunks = []

    uri = URI(uri('/tests/stream'))
    Net::HTTP.get_response(uri) do |res|
      res.read_body do |chunk|
        chunks << chunk
      end
    end
    
    assert_equal 2, chunks.size
    assert_equal 'Hello, ', chunks[0]
    assert_equal 'World', chunks[1]
  end
end
