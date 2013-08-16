package org.polycrystal.rubylet;

import java.lang.reflect.Method;
import java.net.URL;
import java.net.URLClassLoader;

import javax.servlet.ServletContext;
import javax.servlet.ServletContextEvent;
import javax.servlet.ServletContextListener;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 * Checks if JRuby is available in the classpath and if not, load it from the
 * context parameter.
 * 
 * <p>TODO: don't check for existing JRuby? Just make this an optional loader.
 * But it may or may not make a difference to load an external JRuby if it's
 * already available in a parent class laoder. 
 *
 * @author Patrick Mahoney <pat@polycrystal.org>
 */
public class ExternalJRubyLoader implements ServletContextListener {
    
    private static Logger logger = LoggerFactory.getLogger(ExternalJRubyLoader.class);
    
    private boolean haveJRuby() {
        try {
            Class.forName("org.jruby.Ruby");
            return true;
        } catch (ClassNotFoundException e) {
            return false;
        }
    }

    /**
     * Mangle the current context class loader by adding jruby.jar.  Assume
     * jruby.jar is in the lib directory below {@code jrubyHome}, which is
     * a string path to a directory on the file system.
     * 
     * @param jrubyHome
     */
    private void mangleClassLoader(final String jrubyHome) {
        final ClassLoader cl = Thread.currentThread().getContextClassLoader();
        if (!(cl instanceof URLClassLoader)) {
            throw new IllegalStateException("can't mangle non-URLClassLoader " + cl.getClass());
        }

        try {
            final Method addURL = URLClassLoader.class.getDeclaredMethod("addURL", URL.class);
            addURL.setAccessible(true);
            addURL.invoke(cl, new URL("file://" + jrubyHome + "/lib/jruby.jar"));
        } catch (Exception e) {
            throw new IllegalStateException(e);
        }
    }

    public void contextInitialized(ServletContextEvent sce) {
        final ServletContext context = sce.getServletContext();
        
        if (haveJRuby()) {
            logger.info("using jruby available from class loader");
        } else {
            final String jrubyHome = context.getInitParameter("rubylet.jrubyHome");
            logger.info("using jruby @ " + jrubyHome);
            mangleClassLoader(jrubyHome);
        }
    }

    public void contextDestroyed(ServletContextEvent sce) {
        // noop
    }

}
