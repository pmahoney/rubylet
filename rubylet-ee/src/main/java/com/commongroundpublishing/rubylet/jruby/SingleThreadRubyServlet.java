package com.commongroundpublishing.rubylet.jruby;

import java.io.IOException;

import javax.servlet.Servlet;
import javax.servlet.ServletConfig;
import javax.servlet.ServletException;
import javax.servlet.ServletRequest;
import javax.servlet.ServletResponse;

import com.commongroundpublishing.rubylet.Restartable;

public class SingleThreadRubyServlet implements Servlet, Restartable {
    
    public void init(ServletConfig config) throws ServletException {
        // TODO Auto-generated method stub
        
    }

    public ServletConfig getServletConfig() {
        // TODO Auto-generated method stub
        return null;
    }

    public void service(ServletRequest req, ServletResponse res)
            throws ServletException, IOException {
        // TODO Auto-generated method stub
        
    }

    public String getServletInfo() {
        // TODO Auto-generated method stub
        return null;
    }

    public void destroy() {
        // TODO Auto-generated method stub
        
    }

    public void restart() throws ServletException {
        // TODO Auto-generated method stub
        
    }

}
