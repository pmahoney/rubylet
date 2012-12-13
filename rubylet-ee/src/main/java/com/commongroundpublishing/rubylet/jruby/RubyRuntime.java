package com.commongroundpublishing.rubylet.jruby;

import javax.servlet.ServletContext;
import javax.servlet.ServletContextEvent;
import javax.servlet.ServletContextListener;

/**
 * Can only belong to one ServletContext.
 * 
 * @author Patrick Mahoney <patrick.mahoney@commongroundpublishing.com>
 */
public class RubyRuntime implements ServletContextListener {
    
    RestartableRuntime runtime;
    
    public void contextInitialized(ServletContextEvent sce) {
        ServletContext context = sce.getServletContext();
        RubyConfig config = new RubyConfig(context);
        runtime = new RestartableRuntime(config);
        RestartableRuntime.setInstance(context, config.getRuntime(), runtime);
    }

    public void contextDestroyed(ServletContextEvent sce) {
        ServletContext context = sce.getServletContext();
        RubyConfig config = new RubyConfig(context);
        RestartableRuntime.removeInstance(context, config.getRuntime());
        runtime.destroy();
        runtime = null;
    }

}
