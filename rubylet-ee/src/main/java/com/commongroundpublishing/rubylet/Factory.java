package com.commongroundpublishing.rubylet;

import javax.servlet.Servlet;
import javax.servlet.ServletConfig;
import javax.servlet.ServletContextListener;
import javax.servlet.ServletException;

import com.commongroundpublishing.rubylet.config.IConfig;

public interface Factory {
    
    public void init(IConfig config);
    
    public void destroy();
    
    public Servlet makeServlet(ServletConfig config) throws ServletException;
    
    public ServletContextListener makeListener(IConfig config);
    
    /**
     * Check if a restart should be triggered, and trigger one if so.
     */
    public void checkRestart();

    /**
     * Register for restart events.
     * 
     * @param r
     */
    public void register(Restartable r);
    
    /**
     * Unregister for restart events.
     * 
     * @param r
     */
    public void unregister(Restartable r);
}
