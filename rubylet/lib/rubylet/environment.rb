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

  # rack.input must use this encoding
  ASCII_8BIT = Encoding.find('ASCII-8BIT')

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
  end

  # @param [javax.servlet.http.HttpServletRequest] req
  def initialize(req)
    @req = req
    @lock = Mutex.new
  end

  def self.not_implemented(*syms)
    syms.each do |sym|
      define_method(sym) do |*args, &block|
        raise NotImplementedError
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
                  :initialize_copy,
                  :keep_if,
                  :key,
                  :rassoc,
                  :reject,
                  :reject!,
                  :replace,
                  :select!,
                  :shift,
                  :value?)

  # methods not overridden, used as-is from super class
  #
  # []=
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
    if header = load_header(key)
      header
    else
      other = fetch_other(key)
      other.nil? ? NOT_FOUND : other
    end
  end

  def get_value(key, default)
  end

  # Attempt to load a header with Rack-land name +name+.  If found,
  # store it in the fronting hash and return the value.
  #
  # @return [String] the value of the header or nil
  def load_header(rname)
    if (sname = rack2servlet(rname)) && (header = @req.getHeader(sname))
      self[rname] = header
    end
  end

  def keys_headers
    @req.getHeaderNames.map { |sname| servlet2rack(sname) }
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
    when 'rack.input'
      # Store in self hash because we can only call #to_io once.
      # Don't need an instance var because once it's in the hash,
      # should never fall through to fetch_other
      io = @req.getInputStream.to_io.binmode
      io.set_encoding(ASCII_8BIT)
      self['rack.input'] = io

    when 'rack.errors'  then Rubylet::Errors.new(@req.servlet_context)
      
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
    when 'SERVER_SOFTWARE' then @req.servlet_context.getServerInfo

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
