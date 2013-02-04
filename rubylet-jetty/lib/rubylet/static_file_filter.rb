module Rubylet
  class StaticFileFilter
    include Java::JavaxServlet::Filter

    attr_reader :dispatcher

    # @param [javax.servlet.FilterConfig] filterConfig
    def init(filterConfig)
      @resource_base = filterConfig.getInitParameter 'resourceBase'
      @dispatcher = filterConfig.getServletContext.getNamedDispatcher('default')
      if @dispatcher.nil?
        raise "no dispatcher named 'default' found"
      end
    end

    def destroy
      # no-op
    end

    def doFilter(req, resp, chain)
      if static_file?(req)
        @dispatcher.forward(req, resp);
      else
        chain.doFilter(req, resp)
      end
    end

  private

    # @param [javax.servlet.http.HttpServletRequest] req
    def static_file?(req)
      File.file?(File.join(@resource_base, req.getPathInfo))
    end
  end
end
