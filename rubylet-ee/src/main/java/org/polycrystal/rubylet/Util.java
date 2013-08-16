package org.polycrystal.rubylet;

import javax.servlet.ServletContext;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import org.polycrystal.rubylet.config.IConfig;

public class Util {
    
    private static final Logger logger = LoggerFactory.getLogger(Util.class);
    
    public static final String RESTARTABLE_RUBY_FACTORY =
            "org.polycrystal.rubylet.jruby.RestartableRubyFactory";

    public static final String RUBY_FACTORY =
            "org.polycrystal.rubylet.jruby.RubyFactory";
    
    public static final String RUNTIME_KEY = "rubylet.runtime";
    
    /**
     * Load the class {@code className} using {@link Class#forName(String)}.
     * Instantiate an object of that class using the no-arg constructor.
     * Cast the object to {@code klass}.
     * 
     * <p>This method should be used to load classes you do not wish to reference
     * directly.  For example, JRuby classes may not be in our classloader initially,
     * so we want those top-level classes to load without requiring any JRuby classes.
     * 
     * @param className
     * @param klass
     * @return
     */
    public static <T> T loadInstance(String className, Class<T> klass) {
        try {
            final Object o = Class.forName(className).newInstance();
            return klass.cast(o);
        } catch (ClassNotFoundException e) {
            throw new IllegalStateException(e);
        } catch (InstantiationException e) {
            throw new IllegalStateException(e);
        } catch (IllegalAccessException e) {
            throw new IllegalStateException(e);
        }
    }

    public static final <A> A assertNotNull(A obj) {
        if (obj == null) {
            throw new IllegalStateException("not initialized");
        }
        
        return obj;
    }

    /**
     * If {@code obj} is null, throw IllegalStateException stating that
     * {@code owner} is not initialized. Otherwise, return {@code obj}
     * 
     * @param owner
     * @param obj
     * @return {@code obj}
     */
    public static final <A> A assertNotNull(Object owner, A obj) {
        if (obj == null) {
            throw new IllegalStateException(owner + " not initialized");
        }
        
        return obj;
    }
    

    /**
     * Get the factory based on the servlet config.  Will use the default factory
     * (created if necessary) if no factory is configured.
     * 
     * @param config
     * @param className
     * @return
     */
    public static Factory getFactory(IConfig config, String className) {
        final String attributeKey;
        final String configuredRuntime = config.get(RUNTIME_KEY);
        if (configuredRuntime != null) {
            attributeKey = RUNTIME_KEY + "." + configuredRuntime;
        } else {
            attributeKey = RUNTIME_KEY + ".default";
        }

        final ServletContext context = config.getServletContext();
        
        // TODO: are webapp parts are started in parallel?
        synchronized (context) {
            Factory factory = (Factory) context.getAttribute(attributeKey);
            if (factory == null) {
                logger.info("making runtime: {}", attributeKey);
                factory = makeFactory(config, className);
                context.setAttribute(attributeKey, factory);
            } else {
                logger.info("reusing runtime {}", attributeKey);
            }
            return factory;
        }
    }
    
    private static Factory makeFactory(IConfig config, String className) {
        final Factory factory = loadInstance(className, Factory.class);
        factory.init(config);
        return factory;
    }

}
