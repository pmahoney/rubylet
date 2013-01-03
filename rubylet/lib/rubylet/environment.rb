require 'rubylet/errors'
require 'rubylet/respond'
require 'rubylet/headers_helper'
require 'thread'

# Rack SPEC requires an instance of Hash, but then we would have to
# translate ahead-of-time all the expected environment keys.  This is
# slow, so we violate the Rack spec to have a lazy hash-like object.
# (One simple benchmark saw 3000 vs. 4300 req/s for eager hash
# vs. lazy hash).
class Rubylet::Environment
  include Enumerable
  include Rubylet::Respond
  include Rubylet::HeadersHelper

  # Used as a 'not found' sentinel in the companion hash
  NOT_FOUND = Object.new.freeze

  # rack response tuple that completes an async response
  ASYNC_COMPLETE = [0.freeze, {}.freeze, [].freeze].freeze

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
    @lock = Mutex.new
  end

  def [](key)
    val = @hash[key]
    if NOT_FOUND.equal?(val)
      if (name = rack2servlet(key)) && (header = @req.getHeader(name))
        header
      else
        fetch_lazy(key)
      end
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
    # go ahead and load all the headers at this point.
    # FIXME: thread safety?
    load_headers

    (@hash.keys + KEYS).uniq.each do |key|
      block.call [key, self[key]]
    end
  end

  def values_at(*keys)
    keys.map { |k| self[k] }
  end

  # Ensure that +startAsync+ has been called on the request object.
  def ensure_async_started
    async_context
  end

  private

  # Copied from JRuby-Rack rack/handler/servlet.rb
  def load_headers
    @req.getHeaderNames.each do |name|
      @hash[servlet2rack(name)] = @req.getHeader(name)
    end
  end

  # Strip a lone slash and also reduce duplicate '/' to a single
  # slash.
  def clean_slashes(str)
    no_dups = str.gsub(%r{/+}, '/')
    no_dups == '/' ? '' : no_dups
  end

  # @return [javax.servlet.AsyncContext]
  def async_context
    @lock.synchronize { @async_context ||= @req.startAsync }
  end

  # The environment key 'async.callback' must be accessed before
  # calling this method.
  #
  # TODO: Rack async doesn't seem to be standardized yet... In
  # particular, Thin provides an 'async.close' that (I think) can be
  # used to close the response connection after streaming in data
  # asynchronously.
  #
  # Currently we support calling async.callback multiple times.  The
  # first call must provide a status and any headers.  Subsequent
  # calls must have a status of 0.  Headers will be ignored.  The
  # final call, which will complete the async response, must have a
  # status of 0, an empty headers hash, and an empty body array.
  #
  # Example Rack application:
  #
  #    require 'thread'
  #
  #    class AsyncExample
  #      def call(env)
  #        cb = env['async.callback']
  #
  #        # commit the status and headers
  #        cb.call [200, {'Content-Type' => 'text/plain'}, []]
  #
  #        Thread.new do
  #          sleep 5                # long task, wait for message, etc.
  #          body = ['Hello, World!']
  #          cb.call [0, {}, body]
  #          cb.call [0, {}, []]
  #        end
  #
  #        throw :async
  #      end
  #    end
  #
  # @param [Array] resp a Rack response array of [status, headers, body]
  def async_respond(resp)
    if ASYNC_COMPLETE == resp
      async_complete
    else
      status, headers, body = resp
      if body.respond_to? :callback
        body.callback &method(:async_complete)
      end
      respond_multi(async_context.response, status, headers, body)
    end
  end

  def async_complete
    async_context.complete
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

    when 'async.callback'
      if @req.respond_to?(:isAsyncSupported) && @req.isAsyncSupported
        method :async_respond
      end
      
    else
      nil
    end
  end
end
