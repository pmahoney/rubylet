package com.commongroundpublishing.rubylet;

import javax.servlet.ServletContextEvent;
import javax.servlet.ServletContextListener;

import com.commongroundpublishing.rubylet.config.ChainedConfig;
import com.commongroundpublishing.rubylet.config.IConfig;
import com.commongroundpublishing.rubylet.config.PrefixedConfig;
import com.commongroundpublishing.rubylet.config.ServletContextConfig;

import static com.commongroundpublishing.rubylet.Util.assertNotNull;

public abstract class RestartableListener implements ServletContextListener, Restartable {

    /*
     * Hack so that web.xml can declare <listener-class>RubyListener.A</listener-class>
     * so that ServletContext parameters can apply to that specific listener.
     */
    public static final class A extends RestartableListener {}
    public static final class B extends RestartableListener {}
    public static final class C extends RestartableListener {}
    public static final class D extends RestartableListener {}
    public static final class E extends RestartableListener {}
    public static final class F extends RestartableListener {}
    public static final class G extends RestartableListener {}
    
    
    private volatile Factory factory;
    
    private volatile IConfig listenerConfig;
    
    private volatile ServletContextListener child;
    
    private volatile ServletContextEvent sce;
    
    public void contextInitialized(ServletContextEvent sce) {
        final IConfig scConfig = new ServletContextConfig(sce.getServletContext());
        final String prefix = "RubyListener." + getClass().getSimpleName() + ".";
        listenerConfig = new PrefixedConfig(prefix, scConfig);
        final IConfig config = new ChainedConfig(listenerConfig, scConfig);

        this.sce = sce;
        factory = Util.getFactory(config, Util.RESTARTABLE_RUBY_FACTORY);
        child = factory.makeListener(listenerConfig);
        
        child.contextInitialized(sce);
    }
    
    public IConfig getListenerConfig() {
        return assertNotNull(this, listenerConfig);
    }
    
    public void restart() {
        assertNotNull(this, child).contextDestroyed(assertNotNull(sce));
        child = factory.makeListener(getListenerConfig());
        child.contextInitialized(assertNotNull(sce));
    }
    
    public void contextDestroyed(ServletContextEvent sce) {
        assertNotNull(this, child).contextDestroyed(sce);
        child = null;
        this.sce = null;
        factory.destroy();
        factory = null;
        listenerConfig = null;
    }

}
