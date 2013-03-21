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
    
    private final Constants c;
    
    public EnvironmentBuilder(Ruby runtime) {
        this.runtime = runtime;
        this.c = Constants.getInstance(runtime);
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
        return c.cRewindableIO.newInstance(runtime.getCurrentContext(),
                                           io,
                                           Block.NULL_BLOCK);
    }
    
    private IRubyObject getRequestMethod(HttpServletRequest req) {
        final String method = req.getMethod();
             if ("GET".equals(method)) { return c.GET; }
        else if ("POST".equals(method)) { return c.POST; }
        else if ("PUT".equals(method)) { return c.PUT; }
        else if ("HEAD".equals(method)) { return c.HEAD; }
        else if ("DELETE".equals(method)) { return c.DELETE; }
        else if ("OPTIONS".equals(method)) { return c.OPTIONS; }
        else {
            return runtime.newString(req.getMethod());
        }
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
        
        env.put(c.JAVA_SERVLET_REQUEST,
                JavaUtil.convertJavaToUsableRubyObject(runtime, req));
        
        env.put(c.PATH_INFO, getPathInfo(req));
        
        env.put(c.QUERY_STRING, stringOrEmpty(req.getQueryString()));
        
        env.put(c.RACK_ERRORS, newRackErrors(req));

        env.put(c.RACK_INPUT, newRackInput(req));

        env.put(c.RACK_MULTIPROCESS, runtime.getFalse());
        env.put(c.RACK_MULTITHREAD, runtime.getTrue());
        env.put(c.RACK_RUN_ONCE, runtime.getFalse());
        
        env.put(c.RACK_URL_SCHEME, stringOrNull(req.getScheme()));

        env.put(c.RACK_VERSION, runtime.getModule("Rack").getConstant("VERSION"));
        
        env.put(c.REMOTE_ADDR, runtime.newString(req.getRemoteAddr()));
        env.put(c.REMOTE_HOST, runtime.newString(req.getRemoteHost()));
        env.put(c.REMOTE_PORT, runtime.newString(Integer.toString(req.getRemotePort())));
        env.put(c.REQUEST_METHOD, getRequestMethod(req));

        env.put(c.REQUEST_PATH, stringOrNull(req.getPathInfo()));
        env.put(c.REQUEST_URI, getRequestUri(req));
        
        /*
         * context path joined with servlet_path, but not nil and empty
         * string rather than '/'.  According to Java Servlet spec,
         * context_path starts with '/' and never ends with '/' (root
         * context returns empty string).  Similarly, servlet_path will be
         * the empty string (for '/*' matches) or '/<path>'.
         */
        env.put(c.SCRIPT_NAME, 
                runtime.newString(req.getContextPath() + req.getServletPath()));
        
        env.put(c.SERVER_NAME, stringOrNull(req.getServerName()));
        env.put(c.SERVER_PORT, stringOrNull(Integer.toString(req.getServerPort())));
        env.put(c.SERVER_PROTOCOL, stringOrNull(req.getProtocol()));
        env.put(c.SERVER_SOFTWARE, stringOrNull(req.getServletContext().getServerInfo()));

        // miscellaneous keys that are not allowed to be 'nil' by Rack, grumble
        {
            final String remoteUser = req.getRemoteUser();
            if (remoteUser != null) {
                env.put(c.REMOTE_USER, runtime.newString(remoteUser));
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
    
    /**
     * Compare strings case insensitively.
     * 
     * @param a must not be null
     * @param b
     * @return
     */
    private boolean match(String a, String b) {
        return a.equalsIgnoreCase(b);
    }
    
    private IRubyObject getRackHeader(Ruby runtime, String str) {
        // test for some common headers
             if (match("Content-Length", str)) { return c.CONTENT_LENGTH; }
        else if (match("Content-Type", str))   { return c.CONTENT_TYPE; }
        else if (match("Host", str))           { return c.HTTP_HOST; }
        else if (match("Accept", str))         { return c.HTTP_ACCEPT; }
        else if (match("User-Agent", str))     { return c.HTTP_USER_AGENT; }
        else if (match("Connection", str))     { return c.HTTP_CONNECTION; }
        else { return runtime.newString(toRackHeader(str)); }
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
