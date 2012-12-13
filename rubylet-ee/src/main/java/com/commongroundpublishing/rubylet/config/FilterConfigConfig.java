package com.commongroundpublishing.rubylet.config;

import java.util.Enumeration;

import javax.servlet.FilterConfig;
import javax.servlet.ServletContext;


public final class FilterConfigConfig implements IConfig{
    
    private final FilterConfig config;

    public FilterConfigConfig(FilterConfig config) {
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
