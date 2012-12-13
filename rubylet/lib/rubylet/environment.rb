require 'monitor'

require 'rubylet/errors'
require 'rubylet/logger'
require 'rubylet/session'

class Rubylet::Environment < Hash
  include MonitorMixin
  
  def initialize(req, servlet)
    super()  # required to initialize MonitorMixin
    
    if req.respond_to?(:isAsyncSupported) && req.isAsyncSupported
      @async_callback_condition = new_cond
      @async_callback = nil
      self['async.callback'] = method(:forward_to_async_callback)
    end

    load_headers(req)
    load(req, servlet)
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
      self[normalize(h)] = req.getHeader(h)
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
    synchronize do
      @async_callback = block
      @async_callback_condition.broadcast
    end
  end

  def forward_to_async_callback(resp)
    synchronize do
      # wait until someone sets @async_callback
      @async_callback_condition.wait_until { @async_callback }
      # pass resp on to the callback
      @async_callback.call(resp)
    end
  end
  private :forward_to_async_callback

  # Load the Rack environment from a servlet request and context.
  #
  # @param [javax.servlet.http.HttpServletRequest] req
  # @param [javax.servlet.ServletContext context
  def load(req, servlet)
    context = servlet.context

    self['REQUEST_METHOD'] = req.getMethod

    # context path joined with servlet_path, but not nil and empty
    # string rather than '/'
    self['SCRIPT_NAME'] =
      begin
        context_path = req.context_path || '/'
        servlet_path = req.servlet_path || ''
        clean_slashes(context_path + servlet_path)
      end

    self['PATH_INFO']         = clean_slashes(req.path_info || '')
    self['QUERY_STRING']      = req.getQueryString || ''
    self['SERVER_NAME']       = req.getServerName
    self['SERVER_PORT']       = req.getServerPort.to_s

    self['rack.version']      = ::Rack::VERSION
    self['rack.url_scheme']   = req.getScheme

    # TODO: this is not rewindable in violation of the Rack
    # spec.  Requiring rewind ability on every request seems
    # a bit much, particularly since it would be trivial to
    # wrap the io in a helper buffer as-needed, but should
    # probably implement this eventually.
    #
    # @see http://rack.rubyforge.org/doc/SPEC.html
    self['rack.input']        = req.getInputStream.to_io

    self['rack.errors']       = Rubylet::Errors.new(context)
    self['rack.multithread']  = true
    self['rack.multiprocess'] = false
    self['rack.run_once']     = false

    if servlet.param('useSessions')
      self['rack.session']      = Rubylet::Session.new(req)
    end

    if servlet.param('userLogger')
      self['rack.logger']       = Rubylet::Logger.new(context)
    end
      
    self['REMOTE_ADDR']       = req.getRemoteAddr
    self['REMOTE_HOST']       = req.getRemoteHost
    self['REMOTE_USER']       = req.getRemoteUser
    self['REMOTE_PORT']       = req.getRemotePort.to_s
    self['REQUEST_PATH']      = req.getPathInfo
    # note, ruby side is URI, java side is URL
    self['REQUEST_URI'] =
      begin
        q = req.getQueryString
        req.getRequestURL.to_s + (q ? ('?' + q) : '')
      end
      
    self['SERVER_PROTOCOL']   = req.getProtocol
    self['SERVER_SOFTWARE']   = context.getServerInfo

    self['java.context_path'] = req.getContextPath
    self['java.path_info']    = req.getPathInfo
    self['java.servlet_path'] = req.getServletPath
  end
  private :load
end
