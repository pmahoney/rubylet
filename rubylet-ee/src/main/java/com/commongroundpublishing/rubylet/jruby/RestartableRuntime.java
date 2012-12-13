package com.commongroundpublishing.rubylet.jruby;

import java.io.File;
import java.util.Collections;
import java.util.LinkedHashSet;
import java.util.Set;
import java.util.concurrent.Semaphore;
import java.util.concurrent.atomic.AtomicLong;
import java.util.concurrent.atomic.AtomicReference;

import javax.servlet.ServletContext;

import org.jruby.embed.ScriptingContainer;

import com.commongroundpublishing.rubylet.Restartable;

public class RestartableRuntime {

    private static final String RUNTIME_KEY_PREFIX = "rubylet.restartableRuntime.";
    
    public static RestartableRuntime getInstance(ServletContext context, String name) {
        return (RestartableRuntime) context.getAttribute(key(name));
    }
    
    public static void setInstance(ServletContext context, String name, RestartableRuntime source) {
        context.setAttribute(key(name), source);
    }

    public static void removeInstance(ServletContext context, String name) {
        context.removeAttribute(key(name));
    }

    private static String key(String keySuffix) {
        return RUNTIME_KEY_PREFIX + keySuffix;
    }


    

    private final Set<Restartable> restartables =
            Collections.synchronizedSet(new LinkedHashSet<Restartable>());
    
    private final Semaphore restartToken = new Semaphore(1);
    
    private final AtomicLong restartedAt = new AtomicLong(System.currentTimeMillis());
    
    protected final RubyConfig config;
    
    
    private final AtomicReference<ScriptingContainer> container =
            new AtomicReference<ScriptingContainer>();

    
    public RestartableRuntime(RubyConfig config) {
        this.config = config;
        container.set(createContainer());
    }
    
    protected void log(String msg) {
        config.getServletContext().log(msg);
    }

    protected void log(String msg, Throwable ex) {
        config.getServletContext().log(msg, ex);
    }
    
    private void restartRestartables() {
        for (Restartable r : restartables) {
            try {
                r.restart();
            } catch (Exception e) {
                log(this + ": error restarting " + r, e);
            }
        }
    }
    
    private void restart(long triggeredAt) {
        final ScriptingContainer old = container.getAndSet(createContainer());
        try {
            restartedAt.set(triggeredAt);
            restartRestartables();
        } finally {
            destroyContainer(old);
        }
    }

    private final class RestartAction implements Runnable {
        
        private final long triggeredAt;
        
        public RestartAction(long triggeredAt) {
            this.triggeredAt = triggeredAt; 
        }
        
        public void run() {
            try {
                restart(triggeredAt);
            } finally {
                restartToken.release();
            }
        }
    }
    
    /**
     * Trigger a restart which will create a new ScriptingContainer object and
     * then restart all Restartables registered with this runtime.
     * 
     * <p>Restarts triggered while a restart is in progress will be ignored,
     * so this method is safe to call repeatedly.
     */
    public void triggerRestart() {
        final long triggeredAt = System.currentTimeMillis();
        
        if (restartToken.tryAcquire()) {
            log(this + ": restart triggered"); 
            final Thread t = new Thread(new RestartAction(triggeredAt));
            t.setDaemon(true);
            t.setName("rubylet-restarter");
            t.start();
        }
    }
    
    public final void register(Restartable r) {
        restartables.add(r);
    }
    
    public final void unregister(Restartable r) {
        restartables.remove(r);
    }
    
    /**
     * Within this runtime, create a new instance from the class given by
     * {@code rubyClass} in Ruby syntax (e.g. "MyProject::MyObject").
     * 
     * @param rubyClass
     * @param returnType
     * @return
     */
    public final <T> T newInstance(final String rubyClass, final Class<T> returnType) {
        final ScriptingContainer container = getRuntime();
        final Object helper = container.runScriptlet("RubyletHelper");
        return container.callMethod(helper, "new_instance", rubyClass, returnType);
    }
    
    public final boolean isOlderThan(File f) {
        return (f.lastModified() > restartedAt.get());
    }

    public ScriptingContainer getRuntime() {
        return container.get();
    }
    
    private ScriptingContainer createContainer() {
        final ScriptingContainerFactory factory = new ScriptingContainerFactory();
        final ScriptingContainer container = factory.makeContainer(config);
        
        container.runScriptlet("require 'rubylet_helper'");
        final Object helper = container.runScriptlet("RubyletHelper");
        container.callMethod(helper, "boot", config, config.getServletContext());

        log(this + ": new container " + container);
        
        return container;
    }
    
    /**
     * Destroy a ScriptingContainer, catching and logging exceptions.
     * 
     * @param container
     */
    private void destroyContainer(ScriptingContainer container) {
        try {
          container.terminate();
          log(this + ": terminated " + container);
        } catch (Exception e) {
            log(this + ": error destroying container " + container, e);
        }
    }

    public void destroy() {
        log(this + ": shutting down");
        
        destroyContainer(container.getAndSet(null));
    }

}
