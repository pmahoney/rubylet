package rubylet;

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

import org.jruby.Ruby;
import org.jruby.RubyClass;
import org.jruby.RubyModule;
import org.jruby.RubyObject;
import org.jruby.anno.JRubyClass;
import org.jruby.runtime.ObjectAllocator;
import org.jruby.runtime.builtin.IRubyObject;

/**
 * Given a @{code resourceBase} init parameter, tests if a file exists under the
 * {@code resourceBase} at the request's path info.  If so, uses the default
 * dispatcher to handler the request.  If not, forwards the request on down
 * the chain.
 * 
 * <p>TODO: rubylet/rack/ext.jar may or may not be the best place for this.
 * It's mainly used by rubylet-rack-handler.
 * 
 * @author Patrick Mahoney <pat@polycrystal.org>
 */
@JRubyClass(name = "Rubylet::StaticFileFilter")
public class StaticFileFilter extends RubyObject implements Filter {

    private static final long serialVersionUID = 1L;
    
    private static final ObjectAllocator ALLOCATOR = new ObjectAllocator() {
        public IRubyObject allocate(Ruby runtime, RubyClass klass) {
            return new StaticFileFilter(runtime, klass);
        }
    };

    public static void create(Ruby runtime) {
        final RubyModule mRubylet = runtime.defineModule("Rubylet");
        final RubyClass cStaticFileFilter =
                mRubylet.defineClassUnder("StaticFileFilter",
                                          runtime.getObject(),
                                          ALLOCATOR);
        cStaticFileFilter.defineAnnotatedMethods(StaticFileFilter.class);
    }
    
    private String resourceBase;
    
    private RequestDispatcher dispatcher;
    
    public StaticFileFilter(Ruby runtime, RubyClass klass) {
        super(runtime, klass);
    }

    @Override
    public void init(FilterConfig filterConfig) throws ServletException {
        resourceBase = filterConfig.getInitParameter("resourceBase");
        dispatcher = filterConfig.getServletContext().getNamedDispatcher("default");
        if (dispatcher == null) {
            throw new IllegalStateException("no dispatcher named 'default' found");
        }
    }

    @Override
    public void doFilter(ServletRequest request, ServletResponse response, FilterChain chain)
            throws IOException, ServletException
   {
        if (isStaticFile(request)) {
            dispatcher.forward(request, response);
        } else {
            chain.doFilter(request, response);
        }
    }
    
    private boolean isStaticFile(HttpServletRequest request) {
        final File file = new File(resourceBase, request.getPathInfo());
        return file.isFile();
    }
    
    private boolean isStaticFile(ServletRequest request) {
        if (request instanceof HttpServletRequest) {
            return isStaticFile((HttpServletRequest) request);
        } else {
            return false;
        }
    }

    @Override
    public void destroy() {
        // noop
    }
}
