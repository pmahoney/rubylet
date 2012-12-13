package com.commongroundpublishing.rubylet.config;

import java.util.ArrayList;
import java.util.Enumeration;
import java.util.Iterator;

import javax.servlet.ServletContext;

/**
 * Wraps another configuration, pulling only those config
 * values with keys beginning with a given prefix.
 * 
 * @author Patrick Mahoney <patrick.mahoney@commongroundpublishing.com>
 *
 */
public class PrefixedConfig implements IConfig {

    private final String prefix;

    private final IConfig config;
    
    public PrefixedConfig(String prefix, IConfig config) {
        this.prefix = prefix;
        this.config = config;
    }

    public ServletContext getServletContext() {
        return config.getServletContext();
    }

    public String get(String name) {
        return config.get(prefix + name);
    }

    public Enumeration<String> getNames() {
        final Enumeration<String> names = config.getNames();
        final ArrayList<String> suffixes = new ArrayList<String>();
        
        while (names.hasMoreElements()) {
            final String name = names.nextElement();
            if (name.startsWith(prefix)) {
                suffixes.add(name.substring(prefix.length()));
            }
        }
        
        final Iterator<String> iter = suffixes.iterator();
        
        return new Enumeration<String>() {

            public boolean hasMoreElements() {
                return iter.hasNext();
            }

            public String nextElement() {
                return iter.next();
            }
        };
    }
    
}
