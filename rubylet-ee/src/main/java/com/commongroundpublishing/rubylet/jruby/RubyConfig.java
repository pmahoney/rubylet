package com.commongroundpublishing.rubylet.jruby;

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

import com.commongroundpublishing.rubylet.Servlet;
import com.commongroundpublishing.rubylet.config.ChainedConfig;
import com.commongroundpublishing.rubylet.config.FilterConfigConfig;
import com.commongroundpublishing.rubylet.config.IConfig;
import com.commongroundpublishing.rubylet.config.ServletConfigConfig;
import com.commongroundpublishing.rubylet.config.ServletContextConfig;

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
     * rubylet.jar).
     * 
     * @return
     */
    public static String getWebInfPath() {
        final String resource = "rubylet_helper.rb";
        final URL url =
                Servlet.class.getClassLoader().getResource(resource);

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
    
    public final String getJrubyHome() {
        return get("jrubyHome", null);
    }
    
    public final Map<String, String> getEnv() {
        return getAllAsMap("env.");
    }

    public final Map<String, String> getGems() {
        return getAllAsMap("gem.");
    }
    
    public final String getRuntime() {
        return get("runtime", null);
    }
    
    public final String getAppRoot() {
        final String webInfPath = getWebInfPath();
        if (webInfPath == null) {
            return getRequired("appRoot");
        } else {
            return get("appRoot", webInfPath);
        }
    }
    
    public final File getWatchFile() {
        return new File(getAppRoot(), get("watchFile", "tmp/restart.txt"));
    }
    
    public final boolean isBundleExec() {
        return Boolean.parseBoolean(get("bundleExec", null));
    }
    
    public final String getBundleGemfile() {
        return get("bundleGemfile", "Gemfile");
    }
    
    public final String getBundleWithout() {
        return get("bundleWithout", "development:test");
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
     * @return
     */
    public final String getServletPath() {
        return get("servletPath", null);
    }
    
    public final String getBoot() {
        return get("boot", "rubylet/servlet");
    }
    
    public final String getServletClass() {
        return get("servletClass", "Rubylet::Servlet");
    }

    public final String getListenerClass() {
        return getRequired("listenerClass");
    }

    public final LocalContextScope getScope() {
        return getEnum("localContextScope", LocalContextScope.THREADSAFE);
    }

    public final CompileMode getCompileMode() {
        return getEnum("compileMode", CompileMode.JIT);
    }

    public final CompatVersion getCompatVersion() {
        return getEnum("compatVersion", CompatVersion.RUBY1_9);
    }
    
}
