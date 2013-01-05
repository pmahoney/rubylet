require 'spec_helper'
require 'rubylet/environment'

module Rack
  VERSION = '0'
end

module Rubylet
  class FakeIO
    def to_io
      self
    end

    def binmode
      self
    end

    def set_encoding(any)
      self
    end
  end

  # Mocks part of the HttpServletRequest api for testing
  class FakeRequest
    def initialize
      # keys downcased for case insensitivity
      @headers = {
        'user-agent' => 'browser 1.0',
        'content-type' => 'text/plain'
      }
    end

    def getMethod
      'GET'
    end

    def servlet_context
      self
    end

    def context
      self
    end

    def getServerInfo
      'Fake Server'
    end

    def getInputStream
      FakeIO.new
    end

    def getHeader(name)
      # this is supposed to be case insensitive
      @headers[name.downcase]
    end

    def getHeaderNames
      @headers.keys
    end

    def method_missing(*args, &block)
      nil
    end
  end

  class ::Hash
    # naive impl.  Rails 3.0 monkey-patches this into Hash
    def reverse_merge!(other)
      other.each do |k,v|
        self[k] = v unless self.has_key?(k)
      end
      self
    end
  end

  describe Environment do
    before do
      @env = Environment.new(FakeRequest.new)
    end

    it 'stores and retrieves values' do
      @env['key'].must_be_nil
      @env['key'] = 'value'
      @env['key'].must_equal 'value'
    end

    it 'gets values from request object' do
      @env['REQUEST_METHOD'].must_equal 'GET'
    end

    it 'allows shadowing of request object values' do
      @env['REQUEST_METHOD'].must_equal 'GET'
      @env['REQUEST_METHOD'] = 'YELLOW'
      @env['REQUEST_METHOD'].must_equal 'YELLOW'
    end

    it 'gets headers from the request object' do
      @env['HTTP_USER_AGENT'].must_equal 'browser 1.0'
      @env['CONTENT_TYPE'].must_equal 'text/plain'
    end

    it 'supports has_key?' do
      @env.has_key?('HTTP_USER_AGENT').must_equal true
      @env.has_key?('HTTP_USER_AGENT').must_equal true

      @env.has_key?('HTTP_NO_HEADER').must_equal false
      @env.has_key?('HTTP_NO_HEADER').must_equal false

      @env.has_key?('REQUEST_METHOD').must_equal true
      @env.has_key?('REQUEST_METHOD').must_equal true
    end

    describe 'each' do
      it 'iterates over only present keys' do
        @env.each do |k,v|
          # REMOTE_ADDR is a lazy key, but nil in FakeRequest
          k.wont_equal 'REMOTE_ADDR'
        end
      end

      it 'iterates and preserves header modifications' do
        @env['HTTP_USER_AGENT'] = 'test agent 123'
        agent = nil
        @env.each do |k,v|
          agent = v if k == 'HTTP_USER_AGENT'
        end
        agent.must_equal 'test agent 123'
      end

      it 'iterates over explicit nil' do
        @env['nil'] = nil
        val = 'not nil'
        @env.each do |k,v|
          val = v if k == 'nil'
        end
        val.must_be_nil
      end
    end

    describe 'merge!' do
      it 'overwrites hash' do
        @env['key'] = 'orig'
        @env.merge!({ 'key' => 'new' })
        @env['key'].must_equal 'new'
      end

      it 'overwrites request object' do
        @env.merge!({ 'REQUEST_METHOD' => 'new' })
        @env['REQUEST_METHOD'].must_equal 'new'
      end

      it 'returns self' do
        env = @env.merge!({ 'key' => 'value' })
        env['REQUEST_METHOD'].must_equal 'GET'
      end
    end

    describe 'reverse_merge!' do
      it 'supports #reverse_merge!' do
        @env.reverse_merge!({ 'key' => 'new' })
        @env['key'].must_equal 'new'
      end

      it 'does not overwrite value' do
        @env['key'] = 'orig'
        @env.reverse_merge!({ 'key' => 'new' })
        @env['key'].must_equal 'orig'
      end

      it 'returns self' do
        env = @env.reverse_merge!({ 'key' => 'value' })
        env['key'].must_equal 'value'
        env['REQUEST_METHOD'].must_equal 'GET'
      end
    end
  end
end
