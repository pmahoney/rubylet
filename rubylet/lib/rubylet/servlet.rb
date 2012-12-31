require 'java'
require 'rack'

module Rubylet
  # Implements the Servlet API in Ruby as a Rack server.
  class Servlet
    include Java::JavaxServlet::Servlet

    attr_reader :servlet_config, :app, :context
    
    # @param [javax.servlet.ServletConfig] servletConfig
    def init(servletConfig)
      @servlet_config = servletConfig
      @context = servletConfig.getServletContext
      
      rackup_file = param('rubylet.rackupFile') || 'config.ru'
      @app, _opts = Rack::Builder.parse_file(rackup_file)

      if defined?(Rails) && defined?(Rails::Application) && (@app < Rails::Application)
        servlet_path = @servlet_config.getInitParameter('rubylet.servletPath')
        relative_root = if servlet_path 
                          File.join(@context.context_path, servlet_path)
                        else
                          @context.context_path
                        end
        app.config.action_controller.relative_url_root = relative_root
        ActionController::Base.config.relative_url_root = relative_root
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
        status, headers, body = app.call(env)  # may throw async
        throw :async if status == -1  # alternate means of indicating async
        respond(resp, env, status, headers, body)
        return  # :async not thrown
      end

      # :async was thrown; this only works since Servlet 3.0
      # web.xml must also have <async-supported>true<async-supported> in
      # all servlets and filters in the chain.
      #
      # TODO: this works in proof-of-concept! anything more todo?
      #
      # TODO: Rack async doesn't seem to be standardized yet... In particular,
      # Thin provides an 'async.close' that (I think) can be used to
      # close the response connection after streaming in data asynchronously.
      # For now, this code only allows a one-time deferal of the body (i.e.
      # when 'async.callback' is called, the body is sent out and the
      # connection closed immediately.)
      #
      # TODO: because of the above, there isn't a way to quickly send headers
      # but then delay the body.
      #
      # Example Rack application:
      #
      #    require 'thread'
      #
      #    class AsyncExample
      #      def call(env)
      #        cb = env['async.callback']
      #
      #        Thread.new do
      #          sleep 5                # long task, wait for message, etc.
      #          body = ['Hello, World!']
      #          cb.call [200, {'Content-Type' => 'text/plain'}, body]
      #        end
      #
      #        throw :async
      #      end
      #    end
      async_context = req.startAsync
      env.on_async_callback do |(status, headers, body)|
        resp = async_context.getResponse
        respond(resp, env, status, headers, body)
        async_context.complete
      end
    end

    private

    def respond(resp, env, status, headers, body)
      resp.setStatus(status)
      headers.each do |k, v|
        resp.setHeader k, v
      end
      # commit the response and send the headers to the client
      resp.flushBuffer

      if body.respond_to? :to_path
        #env['rack.logger'].warn {
        #  "serving static file with ruby: #{body.to_path}"
        #}

        # TODO: faster to user pure java implementation?  Probably better to
        # either not have ruby serve static files or to put some cache out
        # front.
        write_body(body, resp.getOutputStream) { |part| part.to_java_bytes }
      else
        write_body(body, resp.getWriter)
      end
    end

    # Write each part of body with writer.  Optionally transform each
    # part with the given block.  Flush the writer after each
    # part. Ensure body is closed if it responds to :close.  Close the
    # writer.
    def write_body(body, writer)
      begin
        body.each do |part|
          writer.write(block_given? ? yield(part) : part)
          writer.flush
        end
      ensure
        body.close if body.respond_to?(:close) rescue nil
        writer.close
      end
    end
  end
end

require 'rubylet/environment'
