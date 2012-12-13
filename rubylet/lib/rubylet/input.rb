require 'java'
require 'forwardable'

# Wraps servlet InputStream with a buffer to support Rack required #rewind.
class Rubylet::Input
  extend Forwardable
  
  MAX_BUFFER = 500 * 1024  # 500 kiB
  
  def_delegators :@io, :gets, :read, :each, :close
  
  def initialize(req)
    @stream = java.io.BufferedInputStream.new(req.getInputStream,
                                              req.getContentLength)
    if req.getContentLength > 0 && req.getContentLength < MAX_BUFFER
      @stream.mark(req.getContentLength)
    else
      # TODO: buffer to a file or something; use jruby-rack's RewindableInputStream
      req.getServletContext.log(
        "WARN: input stream of size #{req.getContentLength}; " +
        "rack #rewind only supported to first #{MAX_BUFFER/1024} kiB")
      @stream.mark(MAX_BUFFER)
    end
    
    @io = stream.to_io
  end
  
  def rewind
    @stream.reset
  end
end
