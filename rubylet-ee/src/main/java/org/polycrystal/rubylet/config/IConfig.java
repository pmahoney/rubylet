package org.polycrystal.rubylet.config;

import java.util.Enumeration;

import javax.servlet.ServletContext;

public interface IConfig {
    
    public ServletContext getServletContext();
    
    public String get(String name);
    
    public Enumeration<String> getNames();

}
