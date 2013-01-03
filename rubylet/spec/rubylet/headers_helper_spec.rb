require 'spec_helper'
require 'rubylet/headers_helper'

module Rubylet
  class HeadersHelperConcrete
    include HeadersHelper
  end

  describe HeadersHelper do
    before do
      @helper = HeadersHelperConcrete.new
    end

    describe 'rack2servlet' do
      it 'converts rack 2 servlet' do
        @helper.rack2servlet('HTTP_USER_AGENT').must_equal 'USER-AGENT'
      end

      it 'handles Content-(Length|Type)' do
        @helper.rack2servlet('CONTENT_LENGTH').must_equal 'CONTENT-LENGTH'
        @helper.rack2servlet('CONTENT_TYPE').must_equal 'CONTENT-TYPE'
      end

      it 'return nil on non-header' do
        @helper.rack2servlet('NOT_HEADER').must_equal nil
      end
    end

    describe 'servlet2rack' do
      it 'converts rack 2 servlet' do
        @helper.servlet2rack('User-Agent').must_equal 'HTTP_USER_AGENT'
      end

      it 'does not prepend HTTP_ to Content-(Length|Type)' do
        @helper.servlet2rack('Content-Length').must_equal 'CONTENT_LENGTH'
        @helper.servlet2rack('Content-Type').must_equal 'CONTENT_TYPE'
      end
    end
  end
end
