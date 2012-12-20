package com.commongroundpublishing.rubylet.jruby;

import javax.servlet.Servlet;
import javax.servlet.ServletConfig;
import javax.servlet.ServletContextListener;
import javax.servlet.ServletException;

import org.jruby.embed.ScriptingContainer;

import com.commongroundpublishing.rubylet.Restartable;
import com.commongroundpublishing.rubylet.Factory;
import com.commongroundpublishing.rubylet.config.IConfig;

import static com.commongroundpublishing.rubylet.Util.assertNotNull;

public final class RubyFactory implements Factory {
    
    private RubyConfig config;
    
    /**
     * The underlying ScriptingContainer (JRuby runtime)
     */
    private ScriptingContainer container;
    
    /**
     * RubyletHelper object for this container.
     */
    private Object helper;

    public void init(IConfig config) {
        this.config = new RubyConfig(config);
        initContainer();
    }

    public void destroy() {
        helper = null;
        getContainer().terminate();
        container = null;
    }
    
    private void initContainer() {
        container = makeContainer(getConfig());
        container.runScriptlet("require 'rubylet_helper'");
        helper = container.runScriptlet("RubyletHelper");
        boot();
    }
    
    public RubyConfig getConfig() {
        return assertNotNull(this, config);
    }
    
    public Object getHelper() {
        return assertNotNull(this, helper);
    }
    
    public ScriptingContainer getContainer() {
        return assertNotNull(this, container);
    }
        
    public static ScriptingContainer makeContainer(RubyConfig config) {
        // Required global setting for when JRuby fakes up Kernel.system('ruby')
        // calls.
        // Since this is global, other JRuby servlets in this servlet container
        // are affected...
        //
        // TODO: move to a better location in the code?  remove?
        if (config.getJrubyHome() != null) {
            System.setProperty("jruby.home", config.getJrubyHome());
        }
        
        final ScriptingContainer container = new ScriptingContainer(config.getScope());
        
        container.setCompileMode(config.getCompileMode());
        container.setHomeDirectory(config.getJrubyHome());
        container.setCompatVersion(config.getCompatVersion());
        container.setCurrentDirectory(config.getAppRoot());
        // don't propagate ENV to global JVM level
        container.getProvider().getRubyInstanceConfig().setUpdateNativeENVEnabled(false);
        
        return container;
    }

    public <T> T callHelper(String method, Object arg, Class<T> returnType) {
        return getContainer().callMethod(getHelper(), method, arg, returnType);
    }

    public <T> T callHelper(String method, Object[] args, Class<T> returnType) {
        return getContainer().callMethod(getHelper(), method, args, returnType);
    }

    public void boot() {
        final Object[] args = new Object[] {
                getConfig(),
                getConfig().getServletContext()
        };
        callHelper("boot", args, Object.class); 
    }
        
    public <T> T newInstance(String rubyClass, Class<T> returnType) {
        return callHelper("new_instance", rubyClass, returnType);
    }
    
    /**
     * Make and initialize a new ruby Servlet within the ScriptingContainer.  The ruby
     * class and other options are taken from {@code servletConfig}. 
     */
    public Servlet makeServlet(ServletConfig servletConfig) throws ServletException {
        final RubyConfig config = new RubyConfig(servletConfig);
        final Servlet servlet = newInstance(config.getServletClass(), Servlet.class);
        servlet.init(servletConfig);
        return servlet;
    }
    
    public ServletContextListener makeListener(IConfig config) {
        return newInstance((new RubyConfig(config)).getListenerClass(),
                           ServletContextListener.class);
    }
    
    /**
     * No-op because this factory is not restartable.
     */
    public void checkRestart() {}
    
    /**
     * No-op because this factory is not restartable.
     * 
     * @param r
     */
    public void register(Restartable r) {}

    /**
     * No-op because this factory is not restartable.
     * 
     * @param r
     */
    public void unregister(Restartable r) {}

}
