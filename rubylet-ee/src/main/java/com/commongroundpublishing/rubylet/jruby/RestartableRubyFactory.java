package com.commongroundpublishing.rubylet.jruby;

import java.io.File;
import java.util.Collections;
import java.util.LinkedList;
import java.util.List;
import java.util.concurrent.Semaphore;
import java.util.concurrent.atomic.AtomicInteger;

import javax.servlet.Servlet;
import javax.servlet.ServletConfig;
import javax.servlet.ServletContextListener;
import javax.servlet.ServletException;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.commongroundpublishing.rubylet.Restartable;
import com.commongroundpublishing.rubylet.Factory;
import com.commongroundpublishing.rubylet.config.IConfig;

import static com.commongroundpublishing.rubylet.Util.assertNotNull;;

public final class RestartableRubyFactory implements Factory {
    
    private static final Logger logger = LoggerFactory.getLogger(RestartableRubyFactory.class);
    
    private volatile IConfig originalConfig;
    
    private volatile RubyConfig config;
    
    private volatile Factory factory;
    
    private AtomicInteger refCount = new AtomicInteger(0);
    
    /**
     * Creation time of the factory.
     */
    private volatile long createdAt = 0;
    
    private final List<Restartable> restartables =
            Collections.synchronizedList(new LinkedList<Restartable>());

    private final Semaphore restartToken = new Semaphore(1);

    public void init(IConfig config) {
        originalConfig = config;
        this.config = new RubyConfig(config);
        factory = new RubyFactory();
        factory.reference(this);
        createdAt = System.currentTimeMillis();
        factory.init(config);
        logger.info("{}: monitoring {} for restart", this, this.config.getWatchFile());
    }
    
    /**
     * This method should not be called directly.
     * Call {@link #triggerRestart()} to schedule a restart.
     * 
     * <p>During a restart, this object will be in an unusable
     * state, but as long as nothing calls this method directly,
     * it will be reiniitalized properly.
     * 
     * <p>FIXME: If any restartables throw exceptions, the old
     * factory will not be destroyed, and we may leak runtimes...
     */
    private void restart() {
        final Factory oldFactory = assertNotNull(factory);
        factory = null;
        init(assertNotNull(originalConfig));
        
        for (Restartable r : restartables) {
            try {
                r.restart();
            } catch (ServletException e) {
                logger.error("{}: error restarting {}",
                             new Object[] { this, r },
                             e);
            }
        }
        
        oldFactory.unreference(this);  // find unref destroys factory
    }

    public void destroy() {
        getFactory().unreference(this);
        factory = null;
    }
    
    public RubyConfig getConfig() {
        return assertNotNull(this, config);
    }

    public Factory getFactory() {
        return assertNotNull(this, factory);
    }

    public Servlet makeServlet(ServletConfig config) throws ServletException {
        return getFactory().makeServlet(config);
    }
    
    public ServletContextListener makeListener(IConfig config) {
        return getFactory().makeListener(config);
    }
    
    /**
     * Trigger a restart which will create a new ScriptingContainer object and
     * then restart all Restartables registered with this runtime.
     * 
     * <p>Restarts triggered while a restart is in progress will be ignored,
     * so this method is safe to call repeatedly.
     */
    public void triggerRestart() {
        if (restartToken.tryAcquire()) {
            logger.info("{}: restart triggered", this); 
            final Thread t = new Thread(new Runnable() {
                public void run() {
                    try {
                        restart();
                    } finally {
                        restartToken.release();
                    }
                }
            });
            t.setDaemon(true);
            t.setName("rubylet-restarter");
            t.start();
        }
    }
    
    /**
     * Is this factory older than File {@code f}.
     * 
     * @param f
     * @return
     */
    public boolean isOlderThan(File f) {
        return (f.lastModified() > createdAt);
    }

    public void checkRestart() {
        if (isOlderThan(getConfig().getWatchFile())) {
            triggerRestart();
        }
    }
    
    /**
     * Reference this factory and, if an instance of Restartable,
     * register for restart events.
     */
    public void reference(Object o) {
        refCount.incrementAndGet();
        if (o instanceof Restartable) {
            restartables.add((Restartable) o);
        }
    }

   /**
    * Unreference this factory and, if an instance of Restartable,
    * unregister for restart events.
    */
    public void unreference(Object o) {
        if (o instanceof Restartable) {
            restartables.remove((Restartable) o);
        }
        if (refCount.decrementAndGet() <= 0) {
            factory.unreference(this);
        }
    }

}
