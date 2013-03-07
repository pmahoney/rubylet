package rubylet;

import java.io.IOException;
import java.util.Enumeration;

import javax.servlet.http.HttpServletRequest;

import org.jruby.Ruby;
import org.jruby.RubyClass;
import org.jruby.RubyIO;
import org.jruby.RubyModule;
import org.jruby.RubyString;
import org.jruby.anno.JRubyClass;
import org.jruby.javasupport.JavaUtil;
import org.jruby.runtime.Block;
import org.jruby.runtime.ObjectAllocator;
import org.jruby.runtime.builtin.IRubyObject;

@JRubyClass(name = "Rubylet::Environment")
public final class Environment extends Hash {

    private static final long serialVersionUID = 1L;
    
    public static final String PROTOTYPE = "PROTOTYPE";
    
    /**
     * The prototype hash is built using these keys.  They are
     * defined as java objects for fast switch/case to populate
     * a duplicate of the prototype hash.
     */
    public enum Key {
        ASYNC_CALLBACK("async.callback"),
        JAVA_SERVLET_REQUEST("java.servlet_request"),
        PATH_INFO("PATH_INFO"),
        QUERY_STRING("QUERY_STRING"),
        RACK_ERRORS("rack.errors"),
        RACK_INPUT("rack.input"),
        RACK_MULTIPROCESS("rack.multiprocess"),
        RACK_MULTITHREAD("rack.multithread"),
        RACK_RUN_ONCE("rack.run_once"),
        RACK_URL_SCHEME("rack.url_scheme"),
        RACK_VERSION("rack.version"),
        REMOTE_ADDR("REMOTE_ADDR"),
        REMOTE_HOST("REMOTE_HOST"),
        REMOTE_PORT("REMOTE_PORT"),
        REQUEST_METHOD("REQUEST_METHOD"),
        REQUEST_PATH("REQUEST_PATH"),
        REQUEST_URI("REQUEST_URI"),
        SCRIPT_NAME("SCRIPT_NAME"),
        SERVER_NAME("SERVER_NAME"),
        SERVER_PORT("SERVER_PORT"),
        SERVER_PROTOCOL("SERVER_PROTOCOL"),
        SERVER_SOFTWARE("SERVER_SOFTWARE");
        
        private final String name;
        
        private Key(String name) {
            this.name = name;
        }
        
        public String getName() {
            return name;
        }

    }

    private static final ObjectAllocator ALLOCATOR = new ObjectAllocator() {
        public IRubyObject allocate(Ruby runtime, RubyClass klass) {
            return new Environment(runtime, klass);
        }
    };

    public static void create(Ruby runtime) {
        runtime.evalScriptlet("require 'rack'");
        
        final RubyModule rubylet = runtime.defineModule("Rubylet");
        final RubyClass env = rubylet.defineClassUnder("Environment",
                                                       runtime.getModule("Rubylet").getClass("Hash"),
                                                       ALLOCATOR);
        env.defineAnnotatedMethods(Environment.class);
        
        /*
         * Prototype hash has RubyString keys with raw java Key values.
         * These will be converted to RubyObject values in the {@code populate} method.
         */
        final Environment prototype = new Environment(runtime, env);
        for (Key key : Key.values()) {
            final RubyString rubyKey = runtime.newString(key.getName());
            rubyKey.freeze(runtime.getCurrentContext());
            
            env.defineConstant(key.toString(), rubyKey);
            
            prototype.internalPut(rubyKey, JavaUtil.convertJavaToRuby(runtime, key), false);
        }
        env.defineConstant(PROTOTYPE,  prototype);
    }
    
    private static IRubyObject getConstant(Ruby runtime, String name) {
        return runtime.getModule("Rubylet").getClass("Environment").getConstant(name);
    }
    
    /**
     * Duplicate the prototype hash.  Then populate the hash from values
     * in {@req}.
     * 
     * @param runtime
     * @param req
     * @return
     * @throws IOException
     */
    public static Environment dupPrototype(Ruby runtime, HttpServletRequest req) throws IOException {
        final Environment env = (Environment) getConstant(runtime, PROTOTYPE).dup();
        env.populate(runtime, req);
        return env;
    }

    public Environment(Ruby runtime, RubyClass klass) {
        super(runtime, klass);
    }
    
    /**
     * Assumes all current values are raw java Key objects. Populate the rack
     * environment hash by replacing current values with values from the Java
     * servlet request.
     * 
     * <p>Iterating through the entry set of a hash dup'ed from the prototype
     * is faster than building the hash up one-by-one.  Very roughly twice as
     * fast.
     * 
     * @param runtime
     * @param req
     */
    private void populate(Ruby runtime, HttpServletRequest req) throws IOException {
        for (Object _entry : entrySet()) {
            @SuppressWarnings("unchecked")
            final Entry<Object,Object> entry = (Entry<Object,Object>) _entry;
            final Key key = (Key) entry.getValue();
            entry.setValue(fetch(runtime, key, req));
        }
        
        // miscellaneous keys that are not allowed to be 'nil' by Rack, grumble
        {
            final String remoteUser = req.getRemoteUser();
            if (remoteUser != null) {
                final IRubyObject key = runtime.getModule("Rubylet").getConstant("REMOTE_USER");
                put(key, runtime.newString(remoteUser));
            }
        }
        
        addHeaders(req);
    }
    
    /**
     * Add each HTTP header in {@code req} into the hash, translating
     * Servlet header names to their Rack equivalents.
     * 
     * @param req
     */
    private final void addHeaders(HttpServletRequest req) {
        final Ruby runtime = getRuntime();
        final Enumeration<String> names = req.getHeaderNames();
        while (names.hasMoreElements()) {
            final String name = names.nextElement();
            
            final IRubyObject key;
            final IRubyObject value;
            
            if (name.equalsIgnoreCase("Content-Length")) {
                key   = runtime.getModule("Rubylet").getConstant("CONTENT_LENGTH");
                value = runtime.newString(req.getHeader(name));
            } else if (name.equalsIgnoreCase("Content-Type")) {
                key   = runtime.getModule("Rubylet").getConstant("CONTENT_TYPE");
                value = runtime.newString(req.getHeader(name));
            } else {
                key   = runtime.newString("HTTP_" +
                                          name.toUpperCase().replaceAll("-", "_"));
                value = runtime.newString(req.getHeader(name));
            }
            
            put(key, value);
        }
    }
    
    /**
     * Create a new ruby string for {@code str}, or if null,
     * return ruby nil.
     * 
     * @param str
     * @return a new ruby string or ruby nil if {@code str} was null
     */
    private IRubyObject stringOrNull(String str) {
        if (str == null) {
            return getRuntime().getNil();
        } else {
            return getRuntime().newString(str);
        }
    }
    
    /**
     * A *new* empty string because app may modify it (e.g. Ramaze)
     * 
     * @param str
     * @return
     */
    private IRubyObject stringOrEmpty(String str) {
        if (str == null) {
            return RubyString.newEmptyString(getRuntime());
        } else {
            return getRuntime().newString(str);
        }
    }
    
    private IRubyObject fetch(Ruby runtime, Key key, HttpServletRequest req) throws IOException {
        switch (key) {
        case ASYNC_CALLBACK:
            // this is populated in Servlet.
            return runtime.getNil();
        case JAVA_SERVLET_REQUEST:
            return JavaUtil.convertJavaToUsableRubyObject(runtime, req);
        case PATH_INFO:
        {
            // not nil, and empty string rather than '/'
            final String pathInfo = req.getPathInfo();
            if (pathInfo == null || pathInfo.equals("/")) {
                return stringOrEmpty(null);
            } else {
                return runtime.newString(pathInfo);
            }
        }
        case QUERY_STRING:
            return stringOrEmpty(req.getQueryString());
        case RACK_ERRORS:
        {
            final RubyClass errors = runtime.getModule("Rubylet").getClass("Errors");
            final IRubyObject obj = JavaUtil
                    .convertJavaToUsableRubyObject(runtime, req.getServletContext());
            return errors.newInstance(runtime.getCurrentContext(), obj, Block.NULL_BLOCK);
        }
        case RACK_INPUT:
        {
            final RubyIO io = new RubyIO(runtime, req.getInputStream());
            io.binmode();
            // rack requires ascii-8bit.  Encoding is only defined in ruby >= 1.9
            final RubyModule encoding = runtime.getModule("Encoding");
            if (encoding != null) {
                io.set_encoding(runtime.getCurrentContext(), encoding.getConstant("ASCII_8BIT"));
            }

            /*
             * Rack requires a rewindable input stream.  Rubylet::RewindableIO
             * is backed by a memory buffer, spilling into a file buffer.  It
             * is unfortunate that Rack requires this.
             * 
             * TODO: allow some way to *not* wrap io in this rewindable buffer.
             * 
             * @see http://rack.rubyforge.org/doc/SPEC.html
             */
            return runtime.getModule("Rubylet").getClass("RewindableIO")
                    .newInstance(runtime.getCurrentContext(), io, null);
        }
        case RACK_MULTIPROCESS:
            return runtime.getFalse();
        case RACK_MULTITHREAD:
            return runtime.getTrue();
        case RACK_RUN_ONCE:
            return runtime.getFalse();
        case RACK_URL_SCHEME:
            return stringOrNull(req.getScheme());
        case RACK_VERSION:
            return runtime.getModule("Rack").getConstant("VERSION");
        case REMOTE_ADDR:
            return runtime.newString(req.getRemoteAddr());
        case REMOTE_HOST:
            return runtime.newString(req.getRemoteHost());
        case REMOTE_PORT:
            return runtime.newString(Integer.toString(req.getRemotePort()));
        case REQUEST_METHOD:
        {
            // TODO what about methods for which we haven't defined constants. does this work?
            final String method = req.getMethod();
            final IRubyObject val = runtime.getModule("Rubylet").getConstant(method);
            if (val.isNil()) {
                return runtime.newString(method);
            } else {
                return val;
            }
        }
        case REQUEST_PATH:
            return stringOrNull(req.getPathInfo());
        case REQUEST_URI:
        {
            // note, ruby side is URI, java side is URL
            final StringBuffer url = req.getRequestURL();
            final String query = req.getQueryString();
            if (query != null) {
                url.append("?").append(query);
            }
            return runtime.newString(url.toString());
        }
        case SCRIPT_NAME:
            /*
             * context path joined with servlet_path, but not nil and empty
             * string rather than '/'.  According to Java Servlet spec,
             * context_path starts with '/' and never ends with '/' (root
             * context returns empty string).  Similarly, servlet_path will be
             * the empty string (for '/*' matches) or '/<path>'.
             */
            return runtime.newString(req.getContextPath() + req.getServletPath());
        case SERVER_NAME:
            return stringOrNull(req.getServerName());
        case SERVER_PORT:
            return stringOrNull(Integer.toString(req.getServerPort()));
        case SERVER_PROTOCOL:
            return stringOrNull(req.getProtocol());
        case SERVER_SOFTWARE:
            return stringOrNull(req.getServletContext().getServerInfo());
        default:
            throw new IllegalArgumentException(key.toString());
        }
    }

}
