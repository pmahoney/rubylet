require 'java'
require 'rack'
require 'rubylet/environment'
require 'rubylet/respond'

module Rubylet
  # Implements the Servlet API in Ruby as a Rack server.
  class Servlet
    include Java::JavaxServlet::Servlet
    include Rubylet::Respond

    attr_reader :servlet_config, :app, :context
    
    # @param [javax.servlet.ServletConfig] servletConfig
    def init(servletConfig)
      @servlet_config = servletConfig
      @context = servletConfig.getServletContext

      # Rails changed how this is configured
      # (ActionController::Base.relative_root=,
      # ActionControler::Base.config.relative_root=,
      # app.config.action_controller.relative_root=).  Hopefully
      # setting the env var takes care of all cases.
      #
      # TODO: some rubylet-ee integration tests test this, but
      # rubylet's integrations touch more versions of rails
      ENV['RAILS_RELATIVE_URL_ROOT'] = relative_root
      
      rackup_file = param('rubylet.rackupFile') || 'config.ru'
      @app, _opts = Rack::Builder.parse_file(rackup_file)
    end

    def relative_root
      if servlet_path = @servlet_config.getInitParameter('rubylet.servletPath')
        File.join(@context.context_path, servlet_path)
      else
        @context.context_path
      end
    end
    
    # def param(config, name)
    #   config.getInitParameter(name) ||
    #     config.getServletContext.getInitParameter(name)
    # end

    def param(name)
      @servlet_config.getInitParameter(name) ||
        @servlet_config.getServletContext.getInitParameter(name)
    end
    
    def destroy
      # no-op
    end

    def to_s
      "#<#{self.class} @app=#{@app}>"
    end

    alias :servlet_info :to_s

    # @param [javax.servlet.ServletRequest] req a Java servlet request,
    # assumed to be an HttpServletRequest
    #
    # @param [javax.servlet.ServletResponse] resp a Java servlet response
    # assumed to be an HttpServletResponse
    def service(req, resp)
      env = Environment.new(req)
      
      catch(:async) do
        # app may throw :async
        status, headers, body = @app.call(env)

        # status of -1 also starts :async
        unless status == -1
          respond(resp, status, headers, body)
          return
        end
      end

      # :async was thrown so we skip the respond() call and assume the
      # app will respond via env['async.callback']; requires Servlet
      # 3.0. The web.xml must also have
      # <async-supported>true<async-supported> in all servlets and
      # filters in the chain.
      #
      # Before this method returns, we need to ensure #startAsync has
      # been called on the request, so we force env to do so.
      env.ensure_async_started
    end
  end
end
