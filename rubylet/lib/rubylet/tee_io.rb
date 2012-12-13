# All reads on +io+ are copied to +out+.  Only supports IO methods
# specified by Rack Input Stream spec.
module Rubylet
  class TeeIO
    def initialize(io, out)
      @io = io
      @out = out
    end

    # Does not support custom separator per Rack spec
    def gets
      str = @io.gets
      @out.write(str) if str
      str
    end

    def read(length = nil, buffer = nil)
      str = ''
      ret = @io.read(length, str)
      @out.write(str)
      if buffer
        buffer << str
        if ret.object_id == str.object_id
          buffer
        else
          ret
        end
      else
        ret
      end
    end

    def each
      while s = gets
        yield s
      end
    end

    def close
      @io.close
    end
  end
end
