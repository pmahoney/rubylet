package com.commongroundpublishing.rubylet.jruby;

import javax.servlet.ServletContext;
import javax.servlet.ServletContextEvent;
import javax.servlet.ServletContextListener;
import javax.servlet.ServletException;

import com.commongroundpublishing.rubylet.config.PrefixedConfig;
import com.commongroundpublishing.rubylet.config.ServletContextConfig;

public abstract class RubyListener extends AbstractWrapper<ServletContextListener> implements ServletContextListener {
    
    ServletContext context;
    
    /*
     * Hack so that web.xml can declare <listener-class>RubyListener.A</listener-class>
     * so that ServletContext parameters can apply to that specific listener.
     */
    public static final class A extends RubyListener {}
    public static final class B extends RubyListener {}
    public static final class C extends RubyListener {}
    public static final class D extends RubyListener {}
    public static final class E extends RubyListener {}
    public static final class F extends RubyListener {}
    public static final class G extends RubyListener {}
    
    protected ServletContextListener createChild() {
        // e.g. RubyListener.A.require
        final String rubyClass = getConfig().getListenerClass();
        
        final ServletContextListener child =
                getRuntime().newInstance(rubyClass, ServletContextListener.class);
        log("created new " + rubyClass);
        child.contextInitialized(new ServletContextEvent(getContext()));
        log("initialized " + child);
        
        return child;
    }
    
    protected final void destroyChild(ServletContextListener child) {
        child.contextDestroyed(new ServletContextEvent(getContext()));
        log("destroyed " + child);
    }
    
    protected final ServletContext getContext() {
        return assertNotNullAndReturn(context);
    }
    
    protected final void setContext(ServletContext context) {
        this.context = context;
    }
    
    public final void contextInitialized(ServletContextEvent sce) {
        setContext(sce.getServletContext());

        final String prefix = "RubyListener." + this.getClass().getSimpleName() + ".";
        try {
            final ServletContextConfig base = new ServletContextConfig(sce.getServletContext());
            final PrefixedConfig prefixed = new PrefixedConfig(prefix, base);
            initialize(new RubyConfig(prefixed));
        } catch (ServletException e) {
            throw new IllegalStateException(e);
        }
    }

    public final void contextDestroyed(ServletContextEvent sce) {
        terminate();
        setContext(null);
    }

}
