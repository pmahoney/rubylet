package com.commongroundpublishing.rubylet;

import javax.servlet.ServletContext;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.commongroundpublishing.rubylet.config.IConfig;

public class Util {
    
    private static final Logger logger = LoggerFactory.getLogger(Util.class);
    
    public static final String RESTARTABLE_RUBY_FACTORY =
            "com.commongroundpublishing.rubylet.jruby.RestartableRubyFactory";

    public static final String RUBY_FACTORY =
            "com.commongroundpublishing.rubylet.jruby.RubyFactory";

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
     * Get the factory based on the servlet config.
     * 
     * @param config
     * @param className
     * @return
     */
    public static Factory getFactory(IConfig config, String className) {
        if ("true".equals(config.get("rubylet.uniqueContainer"))) {
            return makeFactory(config, className);
        } else {
            final ServletContext context = config.getServletContext();
            
            // TODO: are webapp parts are started in parallel?
            synchronized (context) {
                Factory factory = (Factory)
                        context.getAttribute("RubyServletFactory");
                if (factory == null) {
                    factory = makeFactory(config, className);
                    context.setAttribute("RubyServletFactory", factory);
                } else {
                    logger.info("reusing factory from servlet context: {}", factory);
                }
                return factory;
            }
        }
    }
    
    private static Factory makeFactory(IConfig config, String className) {
        final Factory factory = loadInstance(className, Factory.class);
        logger.info("new factory: {}", factory);
        factory.init(config);
        return factory;
    }

}
