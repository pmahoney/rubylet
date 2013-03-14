package rubylet.rack;

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
import org.jruby.RubyContinuation;
import org.jruby.RubyHash;
import org.jruby.RubyNumeric;
import org.jruby.RubyObject;
import org.jruby.anno.JRubyClass;
import org.jruby.anno.JRubyMethod;
import org.jruby.runtime.Arity;
import org.jruby.runtime.Block;
import org.jruby.runtime.BlockCallback;
import org.jruby.runtime.CallBlock;
import org.jruby.runtime.ObjectAllocator;
import org.jruby.runtime.ThreadContext;
import org.jruby.runtime.Visibility;
import org.jruby.runtime.builtin.IRubyObject;

@JRubyClass(name = "Rubylet::Rack::Servlet")
public final class Servlet extends RubyObject implements javax.servlet.Servlet {
    
    private static final long serialVersionUID = 1L;
    
    public static void create(Ruby runtime) {
        runtime.evalScriptlet("require 'rack'");

        final RubyClass servlet = runtime.defineModule("Rubylet")
                .defineOrGetModuleUnder("Rack")
                .defineClassUnder("Servlet", runtime.getObject(), ALLOCATOR);

        servlet.defineAnnotatedMethods(Servlet.class);
    }
    
    private static final ObjectAllocator ALLOCATOR = new ObjectAllocator() {

        @Override
        public IRubyObject allocate(Ruby runtime, RubyClass klass) {
            return new Servlet(runtime, klass);
        }
        
    };

    private final RubyClass cAsyncCallback;
    private final IRubyObject asyncCallbackKey;
    private final IRubyObject symAsync;
    
    private IRubyObject app;
    private ServletConfig servletConfig;

    public Servlet(Ruby runtime, RubyClass klass) {
        super(runtime, klass);
        
        cAsyncCallback = runtime.getModule("Rubylet").defineOrGetModuleUnder("Rack").getClass("AsyncCallback");
        asyncCallbackKey = Rubylet.getConstant(runtime, "ASYNC_CALLBACK");
        symAsync = runtime.newSymbol("async");
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

        final Block block = CallBlock.newCallClosure(this, getMetaClass(), Arity.NO_ARGUMENTS, new BlockCallback() {

            @Override
            public IRubyObject call(ThreadContext context, IRubyObject[] _args, Block _block) {
                return app.callMethod(context, "call", env);
            }
            
        }, context);

        /*
         * catch(:async) do
         *   # block body
         * end
         * 
         * If :async is not thrown, returns the result of the block body.
         * 
         * If :async is thrown, returns nil?
         */
        final RubyContinuation rbContinuation = new RubyContinuation(runtime, symAsync);
        try {
            context.pushCatch(rbContinuation.getContinuation());

            final IRubyObject response = rbContinuation.enter(context, symAsync, block);
            if (response.isNil()) {
                // async was thrown
                getAsyncCallback(context, env).ensureStarted();
            } else {
                // response is a Rack response [status, headers, body]
                final RubyArray ary = response.convertToArray();
            
                final int status = RubyNumeric.fix2int(ary.entry(0));
                if (status == -1) {
                    // alternate means of indicating async
                    getAsyncCallback(context, env).ensureStarted();
                } else {
                    final RubyHash headers = ary.entry(1).convertToHash();
                    final IRubyObject body = ary.entry(2);
                    
                    final ResponseHelper wrappedResp = new ResponseHelper(resp, this, getMetaClass());
                    wrappedResp.respond(context, status, headers, body);
                }
            }
        } finally {
            context.popCatch();
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
