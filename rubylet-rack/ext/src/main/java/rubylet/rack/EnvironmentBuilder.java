package rubylet.rack;

import java.io.IOException;
import java.util.Enumeration;

import javax.servlet.http.HttpServletRequest;

import org.jruby.Ruby;
import org.jruby.RubyClass;
import org.jruby.RubyHash;
import org.jruby.RubyIO;
import org.jruby.RubyModule;
import org.jruby.RubyString;
import org.jruby.javasupport.JavaUtil;
import org.jruby.runtime.Block;
import org.jruby.runtime.builtin.IRubyObject;

public final class EnvironmentBuilder {

    private final Ruby runtime;
    
    private RubyString frozenString(String str) {
        final RubyString rbStr = runtime.newString(str);
        rbStr.freeze(runtime.getCurrentContext());
        return rbStr;
    }
    
    // yes, these are instance vars that look like constants.
    //private final RubyString ASYNC_CALLBACK = frozenString("async.callback");
    private final RubyString JAVA_SERVLET_REQUEST;
    private final RubyString PATH_INFO;
    private final RubyString QUERY_STRING;
    private final RubyString RACK_ERRORS;
    private final RubyString RACK_INPUT;
    private final RubyString RACK_MULTIPROCESS;
    private final RubyString RACK_MULTITHREAD;
    private final RubyString RACK_RUN_ONCE;
    private final RubyString RACK_URL_SCHEME;
    private final RubyString RACK_VERSION;
    private final RubyString REMOTE_ADDR;
    private final RubyString REMOTE_HOST;
    private final RubyString REMOTE_PORT;
    private final RubyString REMOTE_USER;
    private final RubyString REQUEST_METHOD;
    private final RubyString REQUEST_PATH;
    private final RubyString REQUEST_URI;
    private final RubyString SCRIPT_NAME;
    private final RubyString SERVER_NAME;
    private final RubyString SERVER_PORT;
    private final RubyString SERVER_PROTOCOL;
    private final RubyString SERVER_SOFTWARE;
    
    private final RubyClass cRewindableIO;
    
    public EnvironmentBuilder(Ruby runtime) {
        this.runtime = runtime;
        
        cRewindableIO = runtime
                .getModule("Rubylet")
                .defineModuleUnder("Rack")
                .getClass("RewindableIO");
        
        JAVA_SERVLET_REQUEST = frozenString("java.servlet_request");
        PATH_INFO = frozenString("PATH_INFO");
        QUERY_STRING = frozenString("QUERY_STRING");
        RACK_ERRORS = frozenString("rack.errors");
        RACK_INPUT = frozenString("rack.input");
        RACK_MULTIPROCESS = frozenString("rack.multiprocess");
        RACK_MULTITHREAD = frozenString("rack.multithread");
        RACK_RUN_ONCE = frozenString("rack.run_once");
        RACK_URL_SCHEME = frozenString("rack.url_scheme");
        RACK_VERSION = frozenString("rack.version");
        REMOTE_ADDR = frozenString("REMOTE_ADDR");
        REMOTE_HOST = frozenString("REMOTE_HOST");
        REMOTE_PORT = frozenString("REMOTE_PORT");
        REMOTE_USER = frozenString("REMOTE_USER");
        REQUEST_METHOD = frozenString("REQUEST_METHOD");
        REQUEST_PATH = frozenString("REQUEST_PATH");
        REQUEST_URI = frozenString("REQUEST_URI");
        SCRIPT_NAME = frozenString("SCRIPT_NAME");
        SERVER_NAME = frozenString("SERVER_NAME");
        SERVER_PORT = frozenString("SERVER_PORT");
        SERVER_PROTOCOL = frozenString("SERVER_PROTOCOL");
        SERVER_SOFTWARE = frozenString("SERVER_SOFTWARE");
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
            return runtime.getNil();
        } else {
            return runtime.newString(str);
        }
    }
    
    /**
     * A *new* empty string because app may modify it (e.g. Ramaze)
     */
    private IRubyObject stringOrEmpty(String str) {
        if (str == null) {
            return RubyString.newEmptyString(runtime);
        } else {
            return runtime.newString(str);
        }
    }
    
    private IRubyObject getPathInfo(HttpServletRequest req) {
        // not nil, and empty string rather than '/'
        final String pathInfo = req.getPathInfo();
        if (pathInfo == null || pathInfo.equals("/")) {
            return stringOrEmpty(null);
        } else {
            return runtime.newString(pathInfo);
        }
    }
    
    private IRubyObject newRackErrors(HttpServletRequest req) {
        final RubyClass errors = runtime.getModule("Rubylet").defineModuleUnder("Rack").getClass("Errors");
        final IRubyObject obj = JavaUtil
                .convertJavaToUsableRubyObject(runtime, req.getServletContext());
        return errors.newInstance(runtime.getCurrentContext(), obj, Block.NULL_BLOCK);
    }
    
    private IRubyObject newRackInput(HttpServletRequest req) throws IOException {
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
        return cRewindableIO.newInstance(runtime.getCurrentContext(),
                                         io,
                                         Block.NULL_BLOCK);
    }
    
    private IRubyObject getRequestMethod(HttpServletRequest req) {
        return runtime.newString(req.getMethod());
        /*
        // TODO what about methods for which we haven't defined constants. does this work?
        final String method = req.getMethod();
        final IRubyObject val = getConstant(method);
        if (val.isNil()) {
            return runtime.newString(method);
        } else {
            return val;
        }
        */
    }

    private IRubyObject getRequestUri(HttpServletRequest req) {
        // note, ruby side is URI, java side is URL
        final StringBuffer url = req.getRequestURL();
        final String query = req.getQueryString();
        if (query != null) {
            url.append("?").append(query);
        }
        return runtime.newString(url.toString());
    }


    public RubyHash newEnvironmentHash(HttpServletRequest req) throws IOException {
        final RubyHash env = RubyHash.newHash(runtime);
        
        env.put(JAVA_SERVLET_REQUEST,
                JavaUtil.convertJavaToUsableRubyObject(runtime, req));
        
        env.put(PATH_INFO, getPathInfo(req));
        
        env.put(QUERY_STRING, stringOrEmpty(req.getQueryString()));
        
        env.put(RACK_ERRORS, newRackErrors(req));

        env.put(RACK_INPUT, newRackInput(req));

        env.put(RACK_MULTIPROCESS, runtime.getFalse());
        env.put(RACK_MULTITHREAD, runtime.getTrue());
        env.put(RACK_RUN_ONCE, runtime.getFalse());
        
        env.put(RACK_URL_SCHEME, stringOrNull(req.getScheme()));

        env.put(RACK_VERSION, runtime.getModule("Rack").getConstant("VERSION"));
        
        env.put(REMOTE_ADDR, runtime.newString(req.getRemoteAddr()));
        env.put(REMOTE_HOST, runtime.newString(req.getRemoteHost()));
        env.put(REMOTE_PORT, runtime.newString(Integer.toString(req.getRemotePort())));
        env.put(REQUEST_METHOD, getRequestMethod(req));

        env.put(REQUEST_PATH, stringOrNull(req.getPathInfo()));
        env.put(REQUEST_URI, getRequestUri(req));
        
        /*
         * context path joined with servlet_path, but not nil and empty
         * string rather than '/'.  According to Java Servlet spec,
         * context_path starts with '/' and never ends with '/' (root
         * context returns empty string).  Similarly, servlet_path will be
         * the empty string (for '/*' matches) or '/<path>'.
         */
        env.put(SCRIPT_NAME, 
                runtime.newString(req.getContextPath() + req.getServletPath()));
        
        env.put(SERVER_NAME, stringOrNull(req.getServerName()));
        env.put(SERVER_PORT, stringOrNull(Integer.toString(req.getServerPort())));
        env.put(SERVER_PROTOCOL, stringOrNull(req.getProtocol()));
        env.put(SERVER_SOFTWARE, stringOrNull(req.getServletContext().getServerInfo()));

        // miscellaneous keys that are not allowed to be 'nil' by Rack, grumble
        {
            final String remoteUser = req.getRemoteUser();
            if (remoteUser != null) {
                env.put(REMOTE_USER, runtime.newString(remoteUser));
            }
        }
        
        addHeaders(runtime, env, req);

        return env;
    }
    
    private static final String RACK_PREFIX = "HTTP_";

    private static final int RACK_PREFIX_LEN = RACK_PREFIX.length();

    private String toRackHeader(String str) {
        final StringBuilder buf =
                new StringBuilder(str.length() + RACK_PREFIX_LEN);
        buf.append(RACK_PREFIX);
        
        for(int i = 0, n = str.length() ; i < n ; i++) { 
            final char c = str.charAt(i);
            if (c == '-') {
                buf.append("_");
            } else {
                buf.append(Character.toUpperCase(c));
            }
        }
        
        return buf.toString();
    }
    
    private IRubyObject getRackHeader(Ruby runtime, String str) {
        return runtime.newString(toRackHeader(str));
        /*
        // test for some common headers
             if ("Content-Length".equals(str)) { return getConstant("CONTENT_LENGTH"); }
        else if ("Content-Type".equals(str))   { return getConstant("CONTENT_TYPE"); }
        else if ("Host".equals(str))           { return getConstant("HTTP_HOST"); }
        else if ("Accept".equals(str))         { return getConstant("HTTP_ACCEPT"); }
        else if ("User-Agent".equals(str))     { return getConstant("HTTP_USER_AGENT"); }
        else if ("Connection".equals(str))     { return getConstant("HTTP_CONNECTION"); }
        else { return runtime.newString(toRackHeader(str)); }
        */
    }
    
    /**
     * Add each HTTP header in {@code req} into the hash, translating
     * Servlet header names to their Rack equivalents.
     * 
     * @param req
     */
    private void addHeaders(Ruby runtime, RubyHash env, HttpServletRequest req) {
        final Enumeration<String> names = req.getHeaderNames();
        while (names.hasMoreElements()) {
            final String name = names.nextElement();
            
            final IRubyObject key   = getRackHeader(runtime, name);
            final IRubyObject value = runtime.newString(req.getHeader(name));
            
            env.put(key, value);
        }
    }

}
