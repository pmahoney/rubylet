package org.polycrystal.rubylet;

import java.io.IOException;

import javax.servlet.Servlet;
import javax.servlet.ServletConfig;
import javax.servlet.ServletException;
import javax.servlet.ServletRequest;
import javax.servlet.ServletResponse;

import org.polycrystal.rubylet.config.IConfig;
import org.polycrystal.rubylet.config.ChainedConfig;
import org.polycrystal.rubylet.config.ServletConfigConfig;
import org.polycrystal.rubylet.config.ServletContextConfig;

import static org.polycrystal.rubylet.Util.assertNotNull;

public final class PlainServlet implements Servlet {

    private ServletConfig servletConfig;
    
    private Factory factory;
    
    private javax.servlet.Servlet child;

    public void init(ServletConfig servletConfig) throws ServletException {
        this.servletConfig = servletConfig;
        final IConfig config =
                new ChainedConfig(new ServletConfigConfig(servletConfig),
                                  new ServletContextConfig(servletConfig.getServletContext()));
        factory = Util.getFactory(config, Util.RUBY_FACTORY);
        factory.reference(this);
        child = factory.makeServlet(servletConfig);
    }

    public ServletConfig getServletConfig() {
        return assertNotNull(this, servletConfig);
    }
    
    public Factory getFactory() {
        return assertNotNull(this, factory);
    }
    
    public javax.servlet.Servlet getChild() {
        return assertNotNull(this, child);
    }

    public void service(ServletRequest req, ServletResponse resp)
            throws ServletException, IOException
    {
            getChild().service(req, resp);
    }

    public String getServletInfo() {
        return getChild().getServletInfo();
    }

    public void destroy() {
        getChild().destroy();
        child = null;
        getFactory().unreference(this);
        factory = null;
        servletConfig = null;
    }

}
