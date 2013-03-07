package rubylet;

import java.io.IOException;

import javax.servlet.ServletConfig;
import javax.servlet.ServletException;
import javax.servlet.ServletRequest;
import javax.servlet.ServletResponse;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;

import org.jruby.Ruby;
import org.jruby.RubyArray;
import org.jruby.RubyClass;
import org.jruby.RubyFixnum;
import org.jruby.RubyHash;
import org.jruby.RubyModule;
import org.jruby.RubyObject;
import org.jruby.anno.JRubyClass;
import org.jruby.anno.JRubyMethod;
import org.jruby.runtime.Block;
import org.jruby.runtime.ObjectAllocator;
import org.jruby.runtime.ThreadContext;
import org.jruby.runtime.Visibility;
import org.jruby.runtime.builtin.IRubyObject;

@JRubyClass(name = "Rubylet::Servlet")
public final class Servlet extends RubyObject implements javax.servlet.Servlet {
    
    private static final long serialVersionUID = 1L;
    
    public static void create(Ruby runtime) {
        runtime.evalScriptlet("require 'rack'");

        final RubyModule rubylet = runtime.defineModule("Rubylet");
        final RubyClass servlet = rubylet.defineClassUnder("Servlet", runtime.getObject(), ALLOCATOR);

        servlet.defineAnnotatedMethods(Servlet.class);
    }
    
    private static final ObjectAllocator ALLOCATOR = new ObjectAllocator() {

        @Override
        public IRubyObject allocate(Ruby runtime, RubyClass klass) {
            return new Servlet(runtime, klass);
        }
        
    };

    private final RubyClass cAsyncCallback;
    private final IRubyObject asyncThrown;
    private final IRubyObject asyncCallbackKey;
    
    private IRubyObject app;
    private ServletConfig servletConfig;

    public Servlet(Ruby runtime, RubyClass klass) {
        super(runtime, klass);
        
        cAsyncCallback = runtime.getModule("Rubylet").getClass("AsyncCallback");
        asyncThrown = runtime.getModule("Rubylet").getConstant("ASYNC_THROWN");
        asyncCallbackKey = runtime.getModule("Rubylet").getClass("Environment")
                .getConstant("ASYNC_CALLBACK");
    }
    
    @JRubyMethod(optional = 1, visibility = Visibility.PRIVATE)
    public IRubyObject initialize(IRubyObject[] args, Block block) {
        if (args.length == 1) {
            this.app = args[0];
        }
        return this;
    }

    @Override
    public void init(ServletConfig config) throws ServletException {
        this.servletConfig = config;

        setRelativeRoot();
        
        // load rack app if we weren't given one in the constructor
        if (app == null) {
            app = loadRackApp();
        }
    }
    
    /**
     * Set RAILS_RELATIVE_URL_ROOT env var in the Ruby runtime so Rails
     * will correctly detect any context path under which the app
     * may be runnning.
     * 
     * <p>Several times, Rails has changed how this is configured
     * {@code ActionController::Base.relative_root=},
     * {@code ActionControler::Base.config.relative_root=},
     * {@code app.config.action_controller.relative_root=}).  Hopefully
     * setting the env var takes care of all cases.
     */
    private void setRelativeRoot() {
        final ServletConfig config = getServletConfig();
        final String servletPath = config.getInitParameter("rubylet.servletPath");

        final String relativeRoot;
        if (servletPath == null) {
            relativeRoot = config.getServletContext().getContextPath();
        } else {
            relativeRoot = config.getServletContext().getContextPath() + servletPath;
        }
    
        final Ruby runtime = getRuntime();
        getRuntime().getENV().op_aset(runtime.getCurrentContext(),
                                      runtime.newString("RAILS_RELATIVE_URL_ROOT"),
                                      runtime.newString(relativeRoot));
    }
    
    private IRubyObject loadRackApp() {
        final ServletConfig config = getServletConfig();
        String rackupFile = config.getInitParameter("rubylet.rackupFile");
        if (rackupFile == null) {
            rackupFile = "config.ru";
        }

        return getRuntime()
                .getModule("Rack")
                .getConstant("Builder")
                .callMethod(getRuntime().getCurrentContext(), "parse_file", getRuntime().newString(rackupFile))
                .convertToArray()
                .first();
    }

    @Override
    public ServletConfig getServletConfig() {
        return servletConfig;
    }
    
    private AsyncCallback getAsyncCallback(ThreadContext context, Environment env) {
        return (AsyncCallback) env.op_aref(context, asyncCallbackKey);
    }

    @Override
    public void service(ServletRequest _req, ServletResponse _resp)
            throws ServletException, IOException
    {
        final Ruby runtime = getRuntime();
        final ThreadContext context = runtime.getCurrentContext();
        final HttpServletRequest req = (HttpServletRequest) _req;
        final HttpServletResponse resp = (HttpServletResponse) _resp;

        final Environment env = Environment.dupPrototype(runtime, req);
        if (req.getServletContext().getEffectiveMajorVersion() >= 3 && req.isAsyncSupported()) {
            env.put(asyncCallbackKey, new AsyncCallback(runtime, cAsyncCallback, req));
        }

        // Servlet#call is implemented in ruby to allow catching :async.  It returns
        // the async sentinel object if the app threw :async.  The app may also return
        // a status of (-1) to start async.
        final IRubyObject response = callMethod("call", app, env);
        
        if (response == asyncThrown) {
            getAsyncCallback(context, env).ensureStarted();
        } else {
            // response is a Rack response [status, headers, body]
            final RubyArray ary = response.convertToArray();
            
            final int status = ((Long) ary.get(0)).intValue();
            if (status == -1) {
                getAsyncCallback(context, env).ensureStarted();
            } else {
                final RubyHash headers = ary.aref(RubyFixnum.one(getRuntime())).convertToHash();
                final IRubyObject body = ary.aref(RubyFixnum.two(getRuntime()));

                final ResponseHelper wrappedResp = new ResponseHelper(resp, this, getMetaClass());
                wrappedResp.respond(context, status, headers, body);
            }
        }
    }

    @Override
    public String getServletInfo() {
        return getMetaClass().toString() + app.toString();
    }

    @Override
    public void destroy() {
        // no-op
    }
    
}
