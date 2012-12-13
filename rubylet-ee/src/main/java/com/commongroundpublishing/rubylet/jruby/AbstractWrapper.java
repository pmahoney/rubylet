package com.commongroundpublishing.rubylet.jruby;

import java.util.concurrent.atomic.AtomicReference;

import javax.servlet.ServletContext;
import javax.servlet.ServletException;

import com.commongroundpublishing.rubylet.Restartable;

/**
 * A Java class that wraps an underlying Ruby class.  Supports restarting
 * by reinitializing the Ruby object.  Assumes a threadsafe Ruby class
 * and a single Ruby runtime.
 * 
 * @author Patrick Mahoney <patrick.mahoney@commongroundpublishing.com>
 *
 * @param <T>
 */
public abstract class AbstractWrapper<T> implements Restartable {
    
    private RubyConfig config;
    
    private RestartableRuntime runtime;
    
    private boolean isDestroyRuntime = false;
    
    private final AtomicReference<T> child = new AtomicReference<T>();
    
    public final <A> A assertNotNullAndReturn(A obj) {
        if (obj == null) {
            throw new IllegalStateException(this + " not initialized");
        }
        
        return obj;
    }

    /**
     * Must be called by subclasses during their initialization
     * (e.g. {@link javax.servlet.Servlet#init(javax.servlet.ServletConfig)}).
     * 
     * @param config
     * @throws ServletException
     */
    protected final void initialize(RubyConfig config) throws ServletException {
        setConfig(config);
        final ServletContext context = config.getServletContext();
        
        if (config.getRuntime() == null) {
            isDestroyRuntime = true;
            runtime = new RestartableRuntime(config);
        } else {
            isDestroyRuntime = false;
            runtime = RestartableRuntime.getInstance(context, config.getRuntime());
        }
        runtime.register(this);
        
        setChild(createChild());
    }
    
    /**
     * Must be called by subclasses during their destruction
     * (e.g. {@link javax.servlet.Servlet#destroy()}).
     */
    protected final void terminate() {
        T oldChild = child.getAndSet(null);
        if (oldChild != null) {
            destroyChild(oldChild);
        } else {
            log("warning: child to destroy was null");
        }
        if (isDestroyRuntime) {
            runtime.destroy();
        }
    }
    
    private final void setChild(T child) {
        this.child.set(child);
    }

    protected final T getChild() {
        return assertNotNullAndReturn(child).get();
    }

    private final void setConfig(RubyConfig config) {
        this.config = config;
    }

    protected final RubyConfig getConfig() {
        return assertNotNullAndReturn(config);
    }
    
    protected final RestartableRuntime getRuntime() {
        return assertNotNullAndReturn(runtime);
    }


    /**
     * Create and initialize a new child object as part of a restart.
     * 
     * @return
     */
    protected abstract T createChild() throws ServletException;

    /**
     * Destroy an old child object as part of a restart.
     * 
     * @param child
     */
    protected abstract void destroyChild(T child);

    public final void restart() throws ServletException {
        destroyChild(child.getAndSet(createChild()));
    }
    
    protected final void log(String msg) {
        getConfig().getServletContext().log(msg);
    }
    
    protected final void log(String msg, Throwable ex) {
        getConfig().getServletContext().log(msg, ex);
    }

}
