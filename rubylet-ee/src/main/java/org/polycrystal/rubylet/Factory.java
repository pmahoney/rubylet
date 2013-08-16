package org.polycrystal.rubylet;

import javax.servlet.Servlet;
import javax.servlet.ServletConfig;
import javax.servlet.ServletContextListener;
import javax.servlet.ServletException;

import org.polycrystal.rubylet.config.IConfig;

public interface Factory {

    /**
     * Initialize the factory according to {@code config}.
     * 
     * @param config
     */
    public void init(IConfig config);
    
    public Servlet makeServlet(ServletConfig config) throws ServletException;
    
    public ServletContextListener makeListener(IConfig config);
    
    /**
     * Check if a restart should be triggered, and trigger one if so.
     */
    public void checkRestart();

    /**
     * Increment the refcount on this Factory.
     * 
     * @param r
     */
    public void reference(Object o);
    
    /**
     * Decrement the refcount on this factory.  If the count falls to zero,
     * the underlying JRuby runtime will be terminated and the factory
     * factory destroyed.
     * 
     * @param r
     */
    public void unreference(Object o);
}
