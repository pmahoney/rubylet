package com.commongroundpublishing.rubylet;

import java.io.IOException;

import javax.servlet.ServletConfig;
import javax.servlet.ServletException;
import javax.servlet.ServletRequest;
import javax.servlet.ServletResponse;

import com.commongroundpublishing.rubylet.config.IConfig;
import com.commongroundpublishing.rubylet.config.ChainedConfig;
import com.commongroundpublishing.rubylet.config.ServletConfigConfig;
import com.commongroundpublishing.rubylet.config.ServletContextConfig;

import static com.commongroundpublishing.rubylet.Util.assertNotNull;

public final class PlainServlet implements javax.servlet.Servlet {

    private ServletConfig servletConfig;
    
    private Factory factory;
    
    private javax.servlet.Servlet child;

    public void init(ServletConfig servletConfig) throws ServletException {
        this.servletConfig = servletConfig;
        final IConfig config =
                new ChainedConfig(new ServletConfigConfig(servletConfig),
                                  new ServletContextConfig(servletConfig.getServletContext()));
        factory = Util.getFactory(config, Util.RUBY_FACTORY);
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
        getFactory().destroy();
        factory = null;
        servletConfig = null;
    }

}
