package com.commongroundpublishing.rubylet;

import javax.servlet.ServletContextEvent;
import javax.servlet.ServletContextListener;

public abstract class Listener implements ServletContextListener {
    
    /*
     * Hack so that web.xml can declare <listener-class>RubyListener.A</listener-class>
     * to that a particular rubyClass may be configured up in the ServletContext. 
     */
    public static final class A extends Listener {}
    public static final class B extends Listener {}
    public static final class C extends Listener {}
    public static final class D extends Listener {}
    public static final class E extends Listener {}
    public static final class F extends Listener {}
    public static final class G extends Listener {}
    
    public static final String RUBY_LISTENER =
            "com.commongroundpublishing.rubylet.jruby.RubyListener";
    
    private ServletContextListener child;

    public void contextInitialized(ServletContextEvent sce) {
        final String suffix = this.getClass().getSimpleName();
        final String klass = RUBY_LISTENER + "$" + suffix;
        child = Util.loadInstance(klass, ServletContextListener.class);
        child.contextInitialized(sce);
    }

    public void contextDestroyed(ServletContextEvent sce) {
        child.contextDestroyed(sce);
    }

}
