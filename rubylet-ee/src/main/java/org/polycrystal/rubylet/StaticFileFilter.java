package org.polycrystal.rubylet;

import java.io.File;
import java.io.IOException;

import javax.servlet.Filter;
import javax.servlet.FilterChain;
import javax.servlet.FilterConfig;
import javax.servlet.RequestDispatcher;
import javax.servlet.ServletException;
import javax.servlet.ServletRequest;
import javax.servlet.ServletResponse;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;

public final class StaticFileFilter implements Filter {
    
    private RequestDispatcher defaultDispatcher;
    
    private String docBase;
    
    private boolean haveDocBase = false;

    public void init(FilterConfig config) throws ServletException {
        defaultDispatcher = config.getServletContext().getNamedDispatcher("default");
        
        docBase = config.getInitParameter("docBase");
        if (docBase == null) {
            docBase = config.getServletContext().getInitParameter("docBase");
        }
        haveDocBase = (docBase != null);
    }

    public void destroy() {
        defaultDispatcher = null;
        docBase = null;
        haveDocBase = false;
    }
    
    private RequestDispatcher getDefaultDispatcher() {
        return Util.assertNotNull(defaultDispatcher);
    }
    
    private String getDocBase() {
        return Util.assertNotNull(docBase);
    }
    
    private boolean haveDocBase() {
        return Util.assertNotNull(haveDocBase);
    }
    
    private boolean canServeStaticFile(HttpServletRequest req) {
        if (haveDocBase()) {
            final File file = new File(getDocBase(), req.getPathInfo());
            return (file.isFile());
        } else {
            if (req.getPathTranslated() == null) {
                return false;
            } else {
                // Glassfish fills getPathTranslated with actual path to file
                // (or dir) if serving from exploded war file or virtual
                // directory.  Presumably Tomcat does the same?
                //
                // Jetty fills getPathTranslated with file path if serving
                // from exploded war (?) or configured resourceBase.
                //
                // TODO: what about other servlet containers?
                final File file = new File(req.getPathTranslated());
                return (file.isFile());
            }
        }
    }
    
    public void doFilter(ServletRequest req0,
                         ServletResponse resp0,
                         FilterChain chain) throws IOException, ServletException {
        
        final HttpServletRequest req = (HttpServletRequest) req0;
        final HttpServletResponse resp = (HttpServletResponse) resp0;
        
        if (canServeStaticFile(req)) {
            getDefaultDispatcher().forward(req, resp);
        } else {
            chain.doFilter(req, resp);
        }
    }

}
