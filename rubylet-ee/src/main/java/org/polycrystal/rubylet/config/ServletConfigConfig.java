package org.polycrystal.rubylet.config;

import java.util.Enumeration;

import javax.servlet.ServletConfig;
import javax.servlet.ServletContext;


public final class ServletConfigConfig implements IConfig{
    
    private final ServletConfig config;

    public ServletConfigConfig(ServletConfig config) {
        this.config = config;
    }
    
    public ServletContext getServletContext() {
        return config.getServletContext();
    }

    public String get(String name) {
        return config.getInitParameter(name);
    }

    public Enumeration<String> getNames() {
        return config.getInitParameterNames();
    }
    
}
