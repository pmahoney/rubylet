package rubylet.rack;

import org.jruby.Ruby;
import org.jruby.RubyClass;
import org.jruby.RubyModule;
import org.jruby.RubyString;
import org.jruby.RubySymbol;
import org.jruby.javasupport.JavaUtil;

/**
 * Convenience class for making some Ruby constants available on the Java side.
 * 
 * @since Mar 20, 2013
 * @author Patrick Mahoney <pat@polycrystal.org>
 */
public final class Constants {
    
    public static RubyModule mRack(Ruby runtime) {
        return runtime.defineModule("Rubylet").defineOrGetModuleUnder("Rack");
    }
    
    /**
     * Get the instance of Constants associated with {@code runtime}.
     * 
     * @param runtime
     * @return
     */
    public static Constants getInstance(Ruby runtime) {
        return (Constants) mRack(runtime)
                .getConstant("CONSTANTS_INSTANCE").toJava(Constants.class);
    }
    
    /**
     * Make and set the instance of Constants for {@code runtime}.
     * 
     * @param runtime
     * @return
     */
    public static Constants makeInstance(Ruby runtime) {
        final Constants constants = new Constants(runtime);
        mRack(runtime).setConstant("CONSTANTS_INSTANCE",
                                   JavaUtil.convertJavaToRuby(runtime, constants));
        return constants;
    }
    
    private final Ruby runtime;
    
    // yes, these are instance vars that look like constants.
    public final RubyString ASYNC_CALLBACK;
    public final RubyString JAVA_SERVLET_REQUEST;
    public final RubyString PATH_INFO;
    public final RubyString QUERY_STRING;
    public final RubyString RACK_ERRORS;
    public final RubyString RACK_INPUT;
    public final RubyString RACK_MULTIPROCESS;
    public final RubyString RACK_MULTITHREAD;
    public final RubyString RACK_RUN_ONCE;
    public final RubyString RACK_URL_SCHEME;
    public final RubyString RACK_VERSION;
    public final RubyString REMOTE_ADDR;
    public final RubyString REMOTE_HOST;
    public final RubyString REMOTE_PORT;
    public final RubyString REMOTE_USER;
    public final RubyString REQUEST_METHOD;
    public final RubyString REQUEST_PATH;
    public final RubyString REQUEST_URI;
    public final RubyString SCRIPT_NAME;
    public final RubyString SERVER_NAME;
    public final RubyString SERVER_PORT;
    public final RubyString SERVER_PROTOCOL;
    public final RubyString SERVER_SOFTWARE;
    
    public final RubyString TRANSFER_ENCODING;

    // some HTTP methods
    public final RubyString GET;
    public final RubyString POST;
    public final RubyString PUT;
    public final RubyString OPTIONS;
    public final RubyString HEAD;
    public final RubyString DELETE;
    
    // Rack versions of some HTTP headers
    public final RubyString CONTENT_LENGTH;
    public final RubyString CONTENT_TYPE;
    public final RubyString HTTP_HOST;
    public final RubyString HTTP_ACCEPT;
    public final RubyString HTTP_USER_AGENT;
    public final RubyString HTTP_CONNECTION;

    
    /**
     * Rubylet::Rack::AsyncCallback
     */
    public final RubyClass cAsyncCallback;
    
    /**
     * Rubylet::Rack::RewindableIO
     */
    public final RubyClass cRewindableIO;

    /**
     * Rubylet::Rack::DechunkingBody
     */
    public final RubyClass cDechunkingBody;

    /**
     * :async
     */
    public final RubySymbol symAsync;

    private Constants(Ruby runtime) {
        this.runtime = runtime;
        
        symAsync = runtime.newSymbol("async");
        
        final RubyModule mRack = runtime
                .getModule("Rubylet")
                .defineOrGetModuleUnder("Rack");

        cAsyncCallback = mRack.getClass("AsyncCallback");

        runtime.evalScriptlet("require 'rubylet/rack/rewindable_io'");
        cRewindableIO = mRack.getClass("RewindableIO");
        
        runtime.evalScriptlet("require 'rubylet/rack/dechunking_body'");
        cDechunkingBody = mRack.getClass("DechunkingBody");
                
        ASYNC_CALLBACK = frozenString("async.callback");
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
        
        TRANSFER_ENCODING = frozenString("Transfer-Encoding");
        
        GET = frozenString("GET");
        POST = frozenString("POST");
        PUT = frozenString("PUT");
        HEAD = frozenString("HEAD");
        OPTIONS = frozenString("OPTIONS");
        DELETE = frozenString("DELETE");
        
        // Rack versions of some HTTP headers
        CONTENT_LENGTH = frozenString("CONTENT_LENGTH");
        CONTENT_TYPE = frozenString("CONTENT_TYPE");
        HTTP_HOST = frozenString("HTTP_HOST");
        HTTP_ACCEPT = frozenString("HTTP_ACCEPT");
        HTTP_USER_AGENT = frozenString("HTTP_USER_AGENT");
        HTTP_CONNECTION = frozenString("HTTP_CONNECTION");
    }
    
    private RubyString frozenString(String str) {
        final RubyString rbStr = runtime.newString(str);
        rbStr.freeze(runtime.getCurrentContext());
        return rbStr;
    }

}
