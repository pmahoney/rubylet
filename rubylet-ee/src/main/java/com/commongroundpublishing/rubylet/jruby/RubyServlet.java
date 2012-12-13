package com.commongroundpublishing.rubylet.jruby;

import java.io.IOException;

import javax.servlet.Servlet;
import javax.servlet.ServletConfig;
import javax.servlet.ServletException;
import javax.servlet.ServletRequest;
import javax.servlet.ServletResponse;

public final class RubyServlet extends AbstractWrapper<Servlet> implements Servlet {
    
    private ServletConfig servletConfig;
    
    protected Servlet createChild() throws ServletException {
        final Servlet servlet = getRuntime()
                .newInstance(getConfig().getServletClass(), Servlet.class);
        log(getServletConfig().getServletName() + ": new servlet instance " + getConfig().getServletClass());
        servlet.init(getServletConfig());
        log(getServletConfig().getServletName() + ": initialized " + servlet);
        return servlet;
    }
    
    protected void destroyChild(Servlet servlet) {
        final String s = servlet.toString();
        servlet.destroy();
        log("destroyed " + s);
    }

    public void init(ServletConfig servletConfig) throws ServletException {
        this.servletConfig = servletConfig;
        initialize(new RubyConfig(servletConfig));
    }

    public void service(ServletRequest req, ServletResponse resp)
            throws ServletException, IOException
    {
        if (getRuntime().isOlderThan(getConfig().getWatchFile())) {
            getRuntime().triggerRestart();
        }

        getChild().service(req, resp);
    }

    public String getServletInfo() {
        return getChild().getServletInfo();
    }

    public ServletConfig getServletConfig() {
        return assertNotNullAndReturn(servletConfig);
    }

    public void destroy() {
        terminate();
    }
    
}
