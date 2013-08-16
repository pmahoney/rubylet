package org.polycrystal.rubylet.jruby;

import java.io.File;
import java.net.MalformedURLException;
import java.net.URL;
import java.util.Collections;
import java.util.Enumeration;
import java.util.HashMap;
import java.util.Map;

import javax.servlet.FilterConfig;
import javax.servlet.ServletConfig;
import javax.servlet.ServletContext;

import org.jruby.CompatVersion;
import org.jruby.RubyInstanceConfig.CompileMode;
import org.jruby.embed.LocalContextScope;

import org.polycrystal.rubylet.Factory;
import org.polycrystal.rubylet.config.ChainedConfig;
import org.polycrystal.rubylet.config.FilterConfigConfig;
import org.polycrystal.rubylet.config.IConfig;
import org.polycrystal.rubylet.config.ServletConfigConfig;
import org.polycrystal.rubylet.config.ServletContextConfig;

public class RubyConfig {
    
    public static String urlPath(String url) {
        try {
            return new URL(url).getPath();
        } catch (MalformedURLException e) {
            return null;
        }
    }
    
    /**
     * Get the path the the WEB-INF folder by assuming
     * "rubylet_helper.rb" can be found on the
     * classpath as a resource inside a JAR file (i.e.
     * rubylet-ee.jar).
     * 
     * @return
     */
    public static String getWebInfPath() {
        final String resource = "rubylet_helper.rb";
        final URL url =
                Factory.class.getClassLoader().getResource(resource);

        // TODO: this works for Jetty.  What about others?
        if (url.getProtocol().equals("jar")) {
            final String p = url.getPath();
            final String search = "/WEB-INF/";
            final int i;
            if ((i = p.indexOf(search)) > 0) {
               return urlPath(p.substring(0, i + search.lastIndexOf("/")));
            }
        }
        
        return null;
    }
    
    private final IConfig config;
    
    public RubyConfig(ServletConfig config) {
        this(new ChainedConfig(new ServletConfigConfig(config),
                               new ServletContextConfig(config.getServletContext())));
    }
    
    public RubyConfig(FilterConfig config) {
        this(new ChainedConfig(new FilterConfigConfig(config),
                               new ServletContextConfig(config.getServletContext())));
    }
    
    public RubyConfig(ServletContext context) {
        this(new ServletContextConfig(context));
    }
    
    public RubyConfig(IConfig config) {
        this.config = config;
    }
    
    public ServletContext getServletContext() {
        return config.getServletContext();
    }

    /**
     * 
     * 
     * @param name
     * @param defaultValue
     * @return
     */
    public final String get(String name, String defaultValue) {
        final String value = config.get(name);
        if (value != null) {
            return value;
        } else {
            return defaultValue;
        }
    }

    /**
     * Get the closest required parameter or throw an exception if it is not set.
     * 
     * @param param
     * @return
     */
    public final String getRequired(String name) {
        final String value = config.get(name);
        if (value == null) {
            throw new IllegalStateException("Missing required value for '" + name + "'");
        }
        return value;
    }

    public final <E extends Enum<E>> E getEnum(String param, E defaultValue) {
        final String name = config.get(param);
        if (name != null) {
            @SuppressWarnings("unchecked")
            Class<E> klass = (Class<E>) defaultValue.getClass();
            return (E) Enum.valueOf(klass, name);
        } else {
            return defaultValue;
        }
    }

    /**
     * Iterate through all init parameters.  For each parameter whose name
     * starts with {@code prefix}, store the corresponding value in a hash
     * using a key derived from the name with the prefix stripped.
     * 
     * @param prefix
     * @return
     */
    public final Map<String, String> getAllAsMap(String prefix) {
        final HashMap<String, String> map = new HashMap<String, String>();
        
        final Enumeration<String> names = config.getNames();
        while (names.hasMoreElements()) {
            final String name = names.nextElement();
            if (name.startsWith(prefix)) {
                final String key = name.substring(prefix.length());
                map.put(key, config.get(name));
            }
        }
        
        return Collections.unmodifiableMap(map);
    }
    
    /**
     * @return JRuby home or null
     */
    public final String getJrubyHome() {
        return get("rubylet.jrubyHome", null);
    }
    
    /**
     * For every key starting with {@code rubylet.env.<NAME>}, make an
     * entry in a map from {@code <NAME>} to the associated value.
     * 
     * <p>This map will be applied as environment variables to a new
     * runtime during boot.
     * 
     * @return the configured environment map
     */
    public final Map<String, String> getEnv() {
        return getAllAsMap("rubylet.env.");
    }

    /**
     * For every key starting with {@code rubylet.gem.<NAME>}, make an
     * entry in a map from {@code <NAME>} to the associated value.
     * 
     * <p>The values must be gem names followed by an optional command
     * and version requirement.  During runtime boot, the gems will
     * be required via {@code rubygems} in spite of any {@code bundler}
     * restrictions.
     * 
     * @return the configured environment map
     */
    public final Map<String, String> getGems() {
        return getAllAsMap("rubylet.gem.");
    }
    
    /**
     * Get the configured runtime.
     * 
     * @return the runtime name, or "default".
     */
    public final String getRuntime() {
        return get("rubylet.runtime", "default");
    }
    
    /**
     * Get the configured appRoot.  If none is configured, attempt to detect
     * the path to the WEB-INF dir of an unpacked WAR file.  The appRoot will
     * then be WEB-INF/classes, which is where Maven will put files in
     * src/main/ruby by default. 
     * 
     * @return the configured appRoot, WEB-INF/classes,
     * or null if unconfigured and the WEB-INF path could not be determined
     */
    public final String getAppRoot() {
        final String webInfPath = getWebInfPath();
        if (webInfPath == null) {
            return getRequired("rubylet.appRoot");
        } else {
            return get("rubylet.appRoot", webInfPath + "/classes");
        }
    }
    
    /**
     * Get a file to monitor for changes after which restarts will be triggered.
     * File must be relative to appRoot.
     * 
     * @return
     */
    public final File getWatchFile() {
        return new File(getAppRoot(), get("rubylet.watchFile", "tmp/restart.txt"));
    }
    
    /**
     * @return true if bundle exec was configured.
     */
    public final boolean isBundleExec() {
        return Boolean.parseBoolean(get("rubylet.bundleExec", null));
    }
    
    /**
     * @return the configured gemfile, or "Gemfile"
     */
    public final String getBundleGemfile() {
        return get("rubylet.bundleGemfile", "Gemfile");
    }

    /**
     * @return the configured bundle "without" values, or "development:test"
     */
    public final String getBundleWithout() {
        return get("rubylet.bundleWithout", "development:test");
    }
    
    /**
     * The servletPath is (in rubylet-tasks) derived from a simple url-pattern
     * of the form '/servletPath/*'.  Complex (or multiple) url-patterns
     * cannot be automatically converted into a servletPath.
     * 
     * <p>This is intended to be concatenated with the context path
     * and then used by rubylet/servlet, for example to set {@code
     * ActionController::Base.config.relative_url_root} in a Rails app.
     * 
     * <p>FIXME: is this used anywhere?
     * 
     * @return
     */
    public final String getServletPath() {
        return get("servletPath", null);
    }
    
    /**
     * @return the configured boot file, which should be relative to appRoot
     */
    public final String getBoot() {
        return get("rubylet.boot", null);
    }
    
    /**
     * @return the configured Ruby class to instantiate as {@link javax.servlet.Servlet}
     */
    public final String getServletClass() {
        return get("rubylet.servletClass", "Rubylet::Rack::Servlet");
    }

    /**
     * @return the configured Ruby class to instantiate as {@link javax.servlet.ServletContextListener}
     */
    public final String getListenerClass() {
        return getRequired("rubylet.listenerClass");
    }

    /**
     * @return the configured LocalContextScope, or {@code LocalContextScope.THREADSAFE}
     */
    public final LocalContextScope getScope() {
        return getEnum("rubylet.localContextScope", LocalContextScope.THREADSAFE);
    }

    public final CompileMode getCompileMode() {
        return getEnum("rubylet.compileMode", CompileMode.JIT);
    }

    public final CompatVersion getCompatVersion() {
        return getEnum("rubylet.compatVersion", CompatVersion.RUBY1_9);
    }
    
}
