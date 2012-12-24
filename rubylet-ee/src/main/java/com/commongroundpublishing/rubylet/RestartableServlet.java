package com.commongroundpublishing.rubylet;

import java.io.IOException;
import java.util.concurrent.atomic.AtomicReference;

import javax.servlet.Servlet;
import javax.servlet.ServletConfig;
import javax.servlet.ServletException;
import javax.servlet.ServletRequest;
import javax.servlet.ServletResponse;

import com.commongroundpublishing.rubylet.config.ChainedConfig;
import com.commongroundpublishing.rubylet.config.IConfig;
import com.commongroundpublishing.rubylet.config.ServletConfigConfig;
import com.commongroundpublishing.rubylet.config.ServletContextConfig;

import static com.commongroundpublishing.rubylet.Util.assertNotNull;

public final class RestartableServlet implements Servlet, Restartable {
    
    private volatile ServletConfig servletConfig;
    
    private volatile Factory factory;
    
    private final AtomicReference<javax.servlet.Servlet> childServlet =
            new AtomicReference<javax.servlet.Servlet>();

    public void init(ServletConfig servletConfig) throws ServletException {
        this.servletConfig = servletConfig;

        final IConfig config =
                new ChainedConfig(new ServletConfigConfig(servletConfig),
                                  new ServletContextConfig(servletConfig.getServletContext()));
        factory = Util.getFactory(config, Util.RESTARTABLE_RUBY_FACTORY);
        factory.reference(this);
        childServlet.set(factory.makeServlet(servletConfig));
    }
    
    public void restart() throws ServletException {
        final javax.servlet.Servlet newChild = getFactory().makeServlet(getServletConfig());
        assertNotNull(childServlet.getAndSet(newChild)).destroy();
    }

    public ServletConfig getServletConfig() {
        return assertNotNull(this, servletConfig);
    }
    
    public Factory getFactory() {
        return assertNotNull(this, factory);
    }
    
    public javax.servlet.Servlet getChild() {
        return assertNotNull(this, childServlet.get());
    }

    public void service(ServletRequest req, ServletResponse resp)
            throws ServletException, IOException
    {
        getFactory().checkRestart();
        getChild().service(req, resp);
    }

    public String getServletInfo() {
        return getChild().getServletInfo();
    }

    public void destroy() {
        assertNotNull(childServlet.getAndSet(null)).destroy();
        getFactory().unreference(this);
        factory = null;
        servletConfig = null;
    }
    
}
