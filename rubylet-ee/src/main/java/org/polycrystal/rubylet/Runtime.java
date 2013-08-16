package org.polycrystal.rubylet;

import static org.polycrystal.rubylet.Util.loadInstance;

import javax.servlet.ServletContextEvent;
import javax.servlet.ServletContextListener;

/**
 * Load RubyRuntime and forward events to it.
 * 
 * @author Patrick Mahoney <pat@polycrystal.org>
 */
public class Runtime implements ServletContextListener {
    
    private ServletContextListener child;

    public void contextInitialized(ServletContextEvent sce) {
        child = loadInstance("org.polycrystal.rubylet.jruby.RubyRuntime",
                             ServletContextListener.class);
        child.contextInitialized(sce);
    }

    public void contextDestroyed(ServletContextEvent sce) {
        child.contextDestroyed(sce);
    }

}
