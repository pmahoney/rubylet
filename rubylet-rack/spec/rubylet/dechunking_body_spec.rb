require 'spec_helper'
require 'rubylet/dechunking_body'

module Rubylet
  describe DechunkingBody do
    def chunk(strs)
      strs.map do |str|
        str.bytesize.to_s(16) + "\r\n" + str + "\r\n"
      end + ["0\r\n\r\n"]
    end

    def dechunk(body)
      ''.tap do |str|
        DechunkingBody.new(body).each { |part| str << part }
      end
    end
    
    it 'de-chunks a chunked body' do
      data = ["some", "data", "\n in chunks."]
      expected = data.join
      assert_equal expected, dechunk(chunk(data))
    end
  end
end
