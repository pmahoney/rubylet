module Demo
  class Servlet
    include Java::JavaxServlet::Servlet

    attr_reader :servlet_config
    
    # @param [javax.servlet.ServletConfig] servletConfig
    def init(servletConfig)
      @servlet_config = servletConfig
    end
    
    def destroy
      # no-op
    end

    alias :servlet_info :to_s

    # @param [javax.servlet.ServletRequest] req a Java servlet request,
    # assumed to be an HttpServletRequest
    #
    # @param [javax.servlet.ServletResponse] resp a Java servlet response
    # assumed to be an HttpServletResponse
    def service(req, resp)
      resp.setStatus(200)
      {
        'Content-Type' => 'text/plain'
      }.each { |k,v| resp.setHeader k, v }
      writer = resp.getWriter
      begin
        writer.println 'Hello, World, direct Ruby impl of javax.servlet.Servlet'
      ensure
        writer.close
      end
    end
  end
end
