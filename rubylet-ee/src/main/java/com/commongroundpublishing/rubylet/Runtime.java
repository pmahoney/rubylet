package com.commongroundpublishing.rubylet;

import static com.commongroundpublishing.rubylet.Util.loadInstance;

import javax.servlet.ServletContextEvent;
import javax.servlet.ServletContextListener;

/**
 * Load RubyRuntime and forward events to it.
 * 
 * @author Patrick Mahoney <patrick.mahoney@commongroundpublishing.com>
 */
public class Runtime implements ServletContextListener {
    
    private ServletContextListener child;

    public void contextInitialized(ServletContextEvent sce) {
        child = loadInstance("com.commongroundpublishing.rubylet.jruby.RubyRuntime",
                             ServletContextListener.class);
        child.contextInitialized(sce);
    }

    public void contextDestroyed(ServletContextEvent sce) {
        child.contextDestroyed(sce);
    }

}
