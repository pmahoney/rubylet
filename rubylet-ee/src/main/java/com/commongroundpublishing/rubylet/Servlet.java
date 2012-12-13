package com.commongroundpublishing.rubylet;

import static com.commongroundpublishing.rubylet.Util.loadInstance;

import java.io.IOException;

import javax.servlet.ServletConfig;
import javax.servlet.ServletException;
import javax.servlet.ServletRequest;
import javax.servlet.ServletResponse;

public class Servlet implements javax.servlet.Servlet {
    
    private javax.servlet.Servlet childServlet;

    public void init(ServletConfig config) throws ServletException {
        childServlet = loadInstance("com.commongroundpublishing.rubylet.jruby.RubyServlet",
                                    javax.servlet.Servlet.class);
        childServlet.init(config);
    }
    
    public void destroy() {
        getChild().destroy();
    }

    public javax.servlet.Servlet getChild() {
        return Util.assertNotNull(childServlet);
    }
    
    /**
     * Forward the http request to child.
     */
    public void service(ServletRequest req, ServletResponse resp)
        throws IOException, ServletException
    {
        getChild().service(req, resp);
    }
    
    public final String getServletInfo() {
        return getChild().getServletInfo();
    }

    public ServletConfig getServletConfig() {
        return getChild().getServletConfig();
    }

}
