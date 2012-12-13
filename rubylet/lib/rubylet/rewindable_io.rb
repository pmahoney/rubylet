require 'rubylet/tee_io'
require 'rubylet/mem_file_io'
require 'stringio'

# Wraps an IO with a memory and file backed buffer to support Rack's
# required #rewind.
#
# Only some IO methods are supported.
module Rubylet
  class RewindableIO
    def initialize(io, limit = MemFileIO::DEFAULT_LIMIT)
      @buf = MemFileIO.new(limit)
      @io = TeeIO.new(io, @buf)
    end

    def gets
      str = @buf.gets
      if str.nil?                 # end of buffer
        @io.gets
      elsif str.end_with?($/)     # good, we got a whole line
        str
      else                        # partial line
        str + (@io.gets || '')
      end
    end

    def read(length = nil, buffer = nil)
      if length.nil? && buffer.nil?
        @buf.read + @io.read
      elsif length.nil?
        @buf.read(nil, buffer)
        @io.read(nil, buffer)
      elsif buffer.nil?
        str = ''
        @buf.read(length, str)
        if (str.size == length)
          @io.read(length - str.size, str)
        end
        str
      else                        # both non-nil
        size0 = buffer.size
        @buf.read(length, buffer)
        from_buf = buffer.size - size0
        if (from_buf < length)
          @io.read(length - from_buf, buffer)
        end
        buffer
      end
    end

    def each
      while s = gets
        yield s
      end
    end

    def rewind
      @buf.rewind
    end

    def close
      @buf.close
      @io.close
    end
  end
end
