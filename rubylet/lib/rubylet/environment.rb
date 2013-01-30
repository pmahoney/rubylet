require 'rubylet/errors'
require 'rubylet/respond'
require 'rubylet/headers_helper'
require 'thread'

# Rack SPEC requires an instance of Hash, which we extend and then
# implement lazy-loading of the environment because loading
# ahead-of-time all the expected environment keys is slow.
#
# There are three levels here: the hash itself, the HTTP headers, and
# the other environment keys.  These are referred to as 'self' or
# 'super', 'headers', and 'other'.
#
# Getting and putting values is not threadsafe.
#
# (One simple benchmark saw 3000 vs. 10000 req/s for eager hash
# vs. lazy hash).
class Rubylet::Environment < Hash
  include Enumerable
  include Rubylet::Respond
  include Rubylet::HeadersHelper

  # It's just bit faster to use constants in a case/when block.
  # Frozen strings are just a small shade faster than un-frozen.
  ASYNC_CALLBACK       = 'async.callback'.freeze
  JAVA_SERVLET_REQUEST = 'java.servlet_request'.freeze
  PATH_INFO            = 'PATH_INFO'.freeze
  QUERY_STRING         = 'QUERY_STRING'.freeze
  RACK_ERRORS          = 'rack.errors'.freeze
  RACK_INPUT           = 'rack.input'.freeze
  RACK_MULTIPROCESS    = 'rack.multiprocess'.freeze
  RACK_MULTITHREAD     = 'rack.multithread'.freeze
  RACK_RUN_ONCE        = 'rack.run_once'.freeze
  RACK_URL_SCHEME      = 'rack.url_scheme'.freeze
  RACK_VERSION         = 'rack.version'.freeze
  REMOTE_ADDR          = 'REMOTE_ADDR'.freeze
  REMOTE_HOST          = 'REMOTE_HOST'.freeze
  REMOTE_PORT          = 'REMOTE_PORT'.freeze
  REMOTE_USER          = 'REMOTE_USER'.freeze
  REQUEST_METHOD       = 'REQUEST_METHOD'.freeze
  REQUEST_PATH         = 'REQUEST_PATH'.freeze
  REQUEST_URI          = 'REQUEST_URI'.freeze
  SCRIPT_NAME          = 'SCRIPT_NAME'.freeze
  SERVER_NAME          = 'SERVER_NAME'.freeze
  SERVER_PORT          = 'SERVER_PORT'.freeze
  SERVER_PROTOCOL      = 'SERVER_PROTOCOL'.freeze
  SERVER_SOFTWARE      = 'SERVER_SOFTWARE'.freeze

  # Other misc string constants
  EMPTY_STRING = ''.freeze
  SLASH        = '/'.freeze
  QUESTION     = '?'.freeze

  # Used as a 'not found' sentinel in the self hash.  Also stored
  # directly in self hash to mark as deleted.
  NOT_FOUND = Object.new.freeze

  # Used as default arg to #fetch, which raises error by default on not found
  RAISE_KEY_ERROR = Object.new.freeze

  # rack response tuple that completes an async response
  ASYNC_COMPLETE = [0.freeze, {}.freeze, [].freeze].freeze

  # keys handled by fetch_other and (initially) not found in @hash
  KEYS_OTHER = %w(
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

  class << self
    # Create an environment as a plain Hash, if the lazy hash will not
    # work for some reason.  This is not ideal, as it calls just
    # #fetch_other for each key (hash could be populated directly).
    #
    # @param [javax.servlet.http.HttpServletRequest] req
    def new_as_hash(req)
      env = new(req)
      hash = {}

      # load all headers
      req.getHeaderNames.each do |sname|
        rname = env.servlet2rack(sname)
        hash[rname] = req.getHeader(sname)
      end

      # load all other keys
      KEYS_OTHER.each do |key|
        value = env.send(:fetch_other, key)
        hash[key] = value if !value.nil?
      end

      # for async stuff, Rubylet::Servlet needs a way to call this
      # method before returning from #service
      hash['rubylet.ensure_async_started'] = env.method(:ensure_async_started)

      hash
    end

    # Create a new lazy Environment object that wraps a Java
    # +HttpServletRequest+.  It acts as a Hash, but most values are
    # not stored in the Hash but fetched from the underlying +req+.
    #
    # @param [javax.servlet.http.HttpServletRequest] req
    def wrap(req)
      env = allocate
      env.send(:initialize, req)
      env
    end

    # Override the constructor to allow zero-arg calls which simply
    # return a new Hash object.  For example, Rails
    # 'active_support/core_ext/hash/slice' calls +env.class.new+ with
    # zero args.
    #
    # To get an actual lazy Environment object, see
    # +Environment.wrap+.
    def new
      Hash.new
    end
  end

  # @param [javax.servlet.http.HttpServletRequest] req
  def initialize(req)
    @req = req
    @lock = Mutex.new
  end

  def self.not_implemented(*syms)
    syms.each do |sym|
      define_method(sym) do |*args, &block|
        raise NotImplementedError, sym.to_s
      end
    end
  end

  # not implemented
  not_implemented(:assoc,
                  :clear,
                  :compare_by_identity,
                  :default,
                  :default=,
                  :default_proc,
                  :default_proc=,
                  :delete_if,
                  :eql?,
                  :flatten,
                  :has_value?,
                  :hash,
                  :keep_if,
                  :key,
                  :rassoc,
                  :reject,
                  :reject!,
                  :select!,
                  :shift,
                  :value?)

  # methods not overridden, used as-is from super class
  #
  # []=
  # initialize_copy, replace
  # reverse_merge! (Rails 3.0 monkeypatch)
  # merge!
  # rehash (?)
  # store
  # update

  # super methods we need to be able to call
  private
  alias :fetch_super :fetch
  alias :keys_super :keys
  public

  def [](key)
    fetch(key, @default)
  end

  def compare_by_identity
    false
  end

  def default(key = nil)
    @default
  end

  def default=(d)
    @default = d
  end

  def delete(key)
    val = fetch(key, NOT_FOUND)
    if NOT_FOUND.equal?(val)
      default
    else
      self[key] = NOT_FOUND
      val
    end
  end

  # TODO: support enumerator version
  def each
    raise NotImplementedError unless block_given?

    keys.each do |key|
      val = fetch(key, NOT_FOUND)
      yield(key,val) unless NOT_FOUND.equal?(val)
    end
  end
  alias :each_pair :each

  # TODO: support enumerator version
  def each_key(&block)
    raise NotImplementedError unless block_given?
    keys.each(&block)
  end

  def each_value(&block)
    to_hash.each_value(&block)
  end

  # There's always at least 'rack.version', and we don't support
  # delete.
  def empty?
    false
  end

  # TODO: is this correct?
  def eql?(other)
    other.to_hash == to_hash
  end
  alias :== :eql?

  # Lookup +key+ in the self hash, headers, or other set.  Return
  # the value (which may be nil if that was explicitly stored in the
  # fronting hash).
  #
  # If not found, raise KeyError, or return +default+ if given, or
  # yield to the block if given.
  def fetch(key, default = RAISE_KEY_ERROR)
    val = fetch_super(key, &method(:fetch_header_or_other))
    if NOT_FOUND.equal?(val)
      if !RAISE_KEY_ERROR.equal?(default)
        default
      elsif block_given?
        yield(key)
      else
        raise KeyError, "#{key} not found"
      end
    else
      val
    end
  end

  def has_key?(key)
    # Note: can't use has_key_super? because we may have stored
    # NOT_FOUND to mark as deleted.
    !NOT_FOUND.equal?(fetch(key, NOT_FOUND))
  end
  alias :include? :has_key?
  alias :key? :has_key?
  alias :member? :has_key?

  def inspect
    to_hash.inspect
  end
  alias :to_s :inspect

  def invert
    to_hash.invert
  end

  def keys
    (keys_super + keys_headers + KEYS_OTHER).uniq
  end

  def length
    keys.length  # somewhat less efficient than one might expect
  end
  alias :size :length

  def merge(other, &block)
    to_hash.merge(other, &block)
  end

  def select(&block)
    to_hash.select(&block)
  end

  def to_a
    a = []
    each { |k,v| a << [k,v] }
    a
  end

  # Load all the values eagerly into a normal Hash
  def to_hash
    h = {}
    each { |k,v| h[k] = v }
    h
  end

  def values
    to_hash.values
  end

  def values_at(*keys)
    keys.map { |k| self[k] }
  end

  ### end overriding of Hash methods ###

  # Ensure that +startAsync+ has been called on the request object.
  def ensure_async_started
    async_context
  end

  private

  # @return a value or NOT_FOUND
  def fetch_header_or_other(key)
    if header = fetch_header(key)
      header
    else
      other = fetch_other(key)
      other.nil? ? NOT_FOUND : other
    end
  end

  def get_value(key, default)
  end

  # Attempt to fetch a header with Rack-land name +name+.  If found,
  # return the value.
  #
  # @return [String] the value of the header or nil
  def fetch_header(rname)
    if sname = rack2servlet(rname)
      @req.getHeader(sname)
    end
  end

  def keys_headers
    @req.getHeaderNames.map { |sname| servlet2rack(sname) }
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
        body.callback(&method(:async_complete))
      end
      respond_multi(async_context.response, status, headers, body)
    end
  end

  def async_complete
    async_context.complete
  end

  # Note: returns nil (and not NOT_FOUND) since some of the calls to
  # java may return nil.  So callers should consider 'nil' as
  # NOT_FOUND.
  #
  # @return a value or nil
  def fetch_other(key)
    case key
    when REQUEST_METHOD then @req.getMethod
  
    # context path joined with servlet_path, but not nil and empty
    # string rather than '/'.  According to Java Servlet spec,
    # context_path starts with '/' and never ends with '/' (root
    # context returns empty string).  Similarly, servlet_path will be
    # the empty string (for '/*' matches) or '/<path>'.
    when SCRIPT_NAME      then @req.context_path + @req.servlet_path

    # constants
    when RACK_VERSION      then ::Rack::VERSION
    when RACK_MULTITHREAD  then true
    when RACK_MULTIPROCESS then false
    when RACK_RUN_ONCE     then false

    # not nil, and empty string rather than '/'
    when PATH_INFO
      case path = @req.path_info
      when nil, SLASH
        EMPTY_STRING.dup
      else
        path
      end
    when QUERY_STRING then @req.getQueryString || EMPTY_STRING.dup
    when SERVER_NAME  then @req.getServerName
    when SERVER_PORT  then @req.getServerPort.to_s

    when RACK_URL_SCHEME then @req.getScheme

    # TODO: this is not rewindable in violation of the Rack
    # spec.  Requiring rewind ability on every request seems
    # a bit much, particularly since it would be trivial to
    # wrap the io in a helper buffer as-needed, but should
    # probably implement this eventually.
    #
    # @see http://rack.rubyforge.org/doc/SPEC.html
    when RACK_INPUT
      # Store in instance var because we can only call #to_io once.
      unless @io
        @io = @req.getInputStream.to_io.binmode
        # rack requires ascii-8bit.  Encoding is only defined in ruby >= 1.9
        @io.set_encoding(Encoding::ASCII_8BIT) if defined?(Encoding::ASCII_8BIT)
      end
      @io

    when RACK_ERRORS  then Rubylet::Errors.new(@req.servlet_context)
      
    when REMOTE_ADDR  then @req.getRemoteAddr
    when REMOTE_HOST  then @req.getRemoteHost
    when REMOTE_USER  then @req.getRemoteUser
    when REMOTE_PORT  then @req.getRemotePort.to_s
    when REQUEST_PATH then @req.getPathInfo

    # note, ruby side is URI, java side is URL
    when REQUEST_URI
      q = @req.getQueryString
      @req.getRequestURL.to_s + (q ? (QUESTION + q) : EMPTY_STRING)
      
    when SERVER_PROTOCOL then @req.getProtocol
    when SERVER_SOFTWARE then @req.servlet_context.getServerInfo

    when JAVA_SERVLET_REQUEST then @req

    when ASYNC_CALLBACK
      if @req.respond_to?(:isAsyncSupported) && @req.isAsyncSupported
        method :async_respond
      end
      
    else
      nil
    end
  end
end
