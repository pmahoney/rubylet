require 'tempfile'

# A memory/file IO buffer.  Data will be written to a memory buffer up
# to a limit, after which a file buffer is used.  Supports Rack input
# stream operations.  Not threadsafe.
module Rubylet::Rack
  class MemFileIO
    DEFAULT_LIMIT = 4096 * 4
    
    # @param [Integer] limit the max size of the first (memory) buffer
    def initialize(limit = DEFAULT_LIMIT)
      @limit = limit
      @mem = StringIO.new
      @file = nil
    end

    def puts(str)
      for_write(str.size + $/.size).puts(str)
    end

    def write(str)
      for_write(str.size).write(str)
    end

    def gets
      for_read.gets
    end

    def read(length = nil, buffer = nil)
      if buffer
        for_read.read(length, buffer)
      else
        for_read.read(length)
      end
    end

    def each(&block)
      for_read.each(&block)
    end

    def rewind
      for_read.rewind
    end

    def close
      for_read.close
    end

    private

    def for_read
      @mem || @file
    end

    def switch_to_file
      mem = @mem
      @mem = nil
      mem.rewind
      @file = make_file(mem.read)
    end

    def for_write(size)
      if @file
        @file
      elsif (@mem.size + size) <= @limit
        @mem
      else
        switch_to_file
        @file
      end
    end

    def make_file(data)
      file = Tempfile.new('MemFileBacking')
      file.unlink
      file.write(data)
      file
    end
  end
end
