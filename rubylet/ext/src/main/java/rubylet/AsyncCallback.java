package rubylet;

import java.io.IOException;

import javax.servlet.AsyncContext;
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
import org.jruby.runtime.Arity;
import org.jruby.runtime.Block;
import org.jruby.runtime.BlockCallback;
import org.jruby.runtime.CallBlock;
import org.jruby.runtime.ThreadContext;
import org.jruby.runtime.builtin.IRubyObject;

/**
 * A rack async callback object that may be used by rack applications
 * to delay or stream responses.
 *
 * <p>TODO: Rack async doesn't seem to be standardized yet... In
 * particular, Thin provides an 'async.close' that (I think) can be
 * used to close the response connection after streaming in data
 * asynchronously.
 *
 * <p>Currently we support calling async.callback multiple times.  The
 * first call must provide a status and any headers.  Subsequent
 * calls must have a status of 0.  Headers will be ignored.  The
 * final call, which will complete the async response, must have a
 * status of 0, an empty headers hash, and an empty body array.
 *
 * <p>Example Rack application:
 *
 * <pre><code>
 *    require 'thread'
 *
 *    class AsyncExample
 *      def call(env)
 *        cb = env['async.callback']
 *
 *        # commit the status and headers
 *        cb.call [200, {'Content-Type' => 'text/plain'}, []]
 *
 *        Thread.new do
 *          sleep 5                # long task, wait for message, etc.
 *          body = ['Hello, World!']
 *          cb.call [0, {}, body]
 *          cb.call [0, {}, []]
 *        end
 *
 *        throw :async
 *      end
 *    end
 *  </code></pre>
 *
 */
@JRubyClass(name = "Rubylet::AsyncCallback")
public final class AsyncCallback extends RubyObject {

    private static final long serialVersionUID = 1L;
    
    public static void create(Ruby runtime) {
        final RubyModule rubylet = runtime.defineModule("Rubylet");
        final RubyClass env = rubylet.defineClassUnder("AsyncCallback",
                                                       runtime.getObject(),
                                                       runtime.getObject().getAllocator());
        env.defineAnnotatedMethods(AsyncCallback.class);
        
        // sentinel object to signal the end of an async response
        runtime.evalScriptlet("Rubylet::AsyncCallback::ASYNC_COMPLETE = " +
                              "[0, {}.freeze, [].freeze].freeze");
    }
    
    private final HttpServletRequest req;
    
    private final IRubyObject asyncComplete;
    
    private AsyncContext asyncContext;

    public AsyncCallback(Ruby runtime, RubyClass klass, HttpServletRequest req) {
        super(runtime, klass);
        this.req = req;
        this.asyncComplete = runtime.getModule("Rubylet")
                .getClass("AsyncCallback")
                .getConstant("ASYNC_COMPLETE");
    }

    /**
     * Ensure {@link HttpServletRequest#startAsync()} has been called.
     */
    public synchronized void ensureStarted() {
        if (asyncContext == null) {
            asyncContext = req.startAsync();
        }
    }
    
    private HttpServletResponse getResponse() {
        return (HttpServletResponse) asyncContext.getResponse();
    }
    
    @JRubyMethod(required = 1)
    public IRubyObject call(ThreadContext context, IRubyObject response) throws IOException {
        ensureStarted();
        
        if (asyncComplete.eql(response)) {
            asyncContext.complete();
        } else {
            final ResponseHelper resp = new ResponseHelper(getResponse(), this, getMetaClass());
            final RubyArray ary = response.convertToArray();
            
            final int status = ((Long) ary.get(0)).intValue();
            final IRubyObject body = ary.aref(RubyFixnum.two(getRuntime()));
            if (status > 0) {
                // first call to callback sends the headers immediately
                final RubyHash headers = ary.aref(RubyFixnum.one(getRuntime())).convertToHash();
                resp.setHeaders(asyncContext.getResponse(), status, headers);
                resp.flush();
                
                if (body.respondsTo("callback")) {
                    // Set a callback which will be called to indicate "complete".
                    // This is an (annoying) alternate to the ASYNC_COMPLETE sentinel.
                    final Block block = CallBlock.newCallClosure(this, getMetaClass(), Arity.NO_ARGUMENTS, new BlockCallback() {

                        @Override
                        public IRubyObject call(ThreadContext context, IRubyObject[] _args, Block _block) {
                            asyncContext.complete();
                            return context.nil;
                        }
                        
                    }, context);

                    body.callMethod(context, "callback", ResponseHelper.ARGS_NONE, block);
                }
                
                resp.writeBodyFlush(context, body);
            } else {
                // second and subsequent calls ignore headers
                resp.writeBodyFlush(context, body);
            }
        }
        
        return context.nil;
    }

}
