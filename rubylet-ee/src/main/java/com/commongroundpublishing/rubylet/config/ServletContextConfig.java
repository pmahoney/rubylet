package com.commongroundpublishing.rubylet.config;

import java.util.Enumeration;

import javax.servlet.ServletContext;


public final class ServletContextConfig implements IConfig {
    
    private final ServletContext context;
    
    public ServletContextConfig(ServletContext context) {
        this.context = context;
    }
    
    public ServletContext getServletContext() {
        return context;
    }

    public String get(String name) {
        return context.getInitParameter(name);
    }

    public Enumeration<String> getNames() {
        return context.getInitParameterNames();
    }

}
