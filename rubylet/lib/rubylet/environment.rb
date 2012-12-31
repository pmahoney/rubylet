require 'monitor'

require 'rubylet/errors'

# Rack SPEC requires an instance of Hash, but then we would have to
# translate ahead-of-time all the expected environment keys.  This is
# slow, so we violate the Rack spec to have a lazy hash-like object.
# (One simple benchmark saw 3000 vs. 4300 req/s for eager hash
# vs. lazy hash).
class Rubylet::Environment
  include Enumerable

  # Used as a 'not found' sentinel in the companion hash
  NOT_FOUND = Object.new.freeze

  # keys handled by fetch_lazy and (initially) not found in @hash
  KEYS = %w(
    REQUEST_METHOD
    SCRIPT_NAME
    rack.version
    rack.multithread
    rack.multiprocess
    rack.run_once
    PATH_INFO
    QUERY_STRING
    SERVER_NAME
    SERVER_PORT
    rack.url_scheme
    rack.input
    rack.errors
    REMOTE_ADDR
    REMOTE_HOST
    REMOTE_USER
    REMOTE_PORT
    REQUEST_PATH
    REQUEST_URI
    SERVER_PROTOCOL
    SERVER_SOFTWARE
    async.callback
    java.servlet_request
    java.context_path
    java.path_info
    java.servlet_path
  )

  # @param [javax.servlet.http.HttpServletRequest] req
  def initialize(req)
    @req = req
    @hash = Hash.new(NOT_FOUND)
    
    load_headers(req)
  end
  
  def normalize(raw)
    if raw =~ /^Content-(Type|Length)$/i
      raw
    else
      'HTTP_' + raw
    end.upcase.gsub(/-/, '_')
  end
  private :normalize

  # Copied from JRuby-Rack rack/handler/servlet.rb
  def load_headers(req)
    req.getHeaderNames.each do |h|
      @hash[normalize(h)] = req.getHeader(h)
    end
  end
  private :load_headers

  # Strip a lone slash and also reduce duplicate '/' to a single
  # slash.
  def clean_slashes(str)
    no_dups = str.gsub(%r{/+}, '/')
    no_dups == '/' ? '' : no_dups
  end
  private :clean_slashes
  
  # Register an async callback.  This block will be called
  # when a Rack application calls the 'async.callback' proc.
  #
  # Calls to 'async.callback' will block until another
  # thread registers a handler by calling this method.
  def on_async_callback(&block)
    @lock.synchronize do
      @async_callback = block
      @async_callback_condition.broadcast
    end
  end

  def forward_to_async_callback(resp)
    @lock.synchronize do
      # wait until someone sets @async_callback
      @async_callback_condition.wait_until { @async_callback }
      # pass resp on to the callback
      @async_callback.call(resp)
    end
  end
  private :forward_to_async_callback

  def [](key)
    val = @hash[key]
    if NOT_FOUND.equal?(val)
      fetch_lazy(key)
    else
      val
    end
  end

  def []=(key, value)
    @hash[key] = value
  end

  def merge!(other)
    @hash.merge!(other)
    self
  end

  def each(&block)
    (@hash.keys + KEYS).uniq.each do |key|
      block.call [key, self[key]]
    end
  end

  def values_at(*keys)
    keys.map { |k| self[k] }
  end

  def fetch_lazy(key)
    context = @req.servlet_context

    case key
    when 'REQUEST_METHOD' then @req.getMethod
  
    # context path joined with servlet_path, but not nil and empty
    # string rather than '/'
    when 'SCRIPT_NAME'
      context_path = @req.context_path || '/'
      servlet_path = @req.servlet_path || ''
      clean_slashes(context_path + servlet_path)

    # constants
    when 'rack.version'      then ::Rack::VERSION
    when 'rack.multithread'  then true
    when 'rack.multiprocess' then false
    when 'rack.run_once'     then false

    when 'PATH_INFO'    then clean_slashes(@req.path_info || '')
    when 'QUERY_STRING' then @req.getQueryString || ''
    when 'SERVER_NAME'  then @req.getServerName
    when 'SERVER_PORT'  then @req.getServerPort.to_s

    when 'rack.url_scheme' then @req.getScheme

    # TODO: this is not rewindable in violation of the Rack
    # spec.  Requiring rewind ability on every request seems
    # a bit much, particularly since it would be trivial to
    # wrap the io in a helper buffer as-needed, but should
    # probably implement this eventually.
    #
    # @see http://rack.rubyforge.org/doc/SPEC.html
    #
    # FIXME instance var set is not threadsafe, but probably ok
    when 'rack.input'
      @rack_input ||= @req.getInputStream.to_io

    when 'rack.errors'  then Rubylet::Errors.new(context)
      
    when 'REMOTE_ADDR'  then @req.getRemoteAddr
    when 'REMOTE_HOST'  then @req.getRemoteHost
    when 'REMOTE_USER'  then @req.getRemoteUser
    when 'REMOTE_PORT'  then @req.getRemotePort.to_s
    when 'REQUEST_PATH' then @req.getPathInfo

    # note, ruby side is URI, java side is URL
    when 'REQUEST_URI'
      q = @req.getQueryString
      @req.getRequestURL.to_s + (q ? ('?' + q) : '')
      
    when 'SERVER_PROTOCOL' then @req.getProtocol
    when 'SERVER_SOFTWARE' then context.getServerInfo

    when 'java.servlet_request' then @req
    when 'java.context_path'    then @req.getContextPath
    when 'java.path_info'       then @req.getPathInfo
    when 'java.servlet_path'    then @req.getServletPath

    # FIXME: instantiating instance vars here is not threadsafe, but
    # perhaps needn't be
    when 'async.callback'
      # if @req.respond_to?(:isAsyncSupported) && req.isAsyncSupported
      @lock = Monitor.new
      @async_callback_condition = @lock.new_cond
      @async_callback = nil
      method(:forward_to_async_callback)

    else
      nil
    end
  end
  private :fetch_lazy
end
