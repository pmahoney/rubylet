package rubylet;

import java.io.IOException;
import java.io.OutputStream;

import javax.servlet.ServletResponse;
import javax.servlet.http.HttpServletResponse;

import org.jruby.RubyHash;
import org.jruby.RubyHash.Visitor;
import org.jruby.RubyModule;
import org.jruby.RubyString;
import org.jruby.runtime.Arity;
import org.jruby.runtime.Block;
import org.jruby.runtime.BlockCallback;
import org.jruby.runtime.CallBlock;
import org.jruby.runtime.ThreadContext;
import org.jruby.runtime.builtin.IRubyObject;

/**
 * Wrapper around an HttpServletResponse that can respond from a Rack
 * {@code [status, headers, body]} tuple.
 * 
 * @author Patrick Mahoney <pat@polycrystal.org>
 *
 */
public final class ResponseHelper {
    
    /**
     * Just an empty array for calling a zero-arg method
     */
    public static final IRubyObject[] ARGS_NONE = new IRubyObject[0];
    
    private final HttpServletResponse resp;
    
    private final IRubyObject self;
    
    private final RubyModule imClass;
    
    public ResponseHelper(HttpServletResponse resp, IRubyObject self, RubyModule imClass) {
        this.resp = resp;
        this.self = self;
        this.imClass = imClass;
    }
    
    public void respond(ThreadContext context,
                        int status,
                        RubyHash headers,
                        IRubyObject body)
            throws IOException
    {
        setHeaders(resp, status, headers);
        
        /*
         * Rails likes to manually chunk the response body.  Servlet container
         * will automatically do this depending on size of body.
         * We have to de-chunk because servlet container can't handle
         * pre-chunked data.
         */
        final IRubyObject value =
                headers.delete(context,
                               context.getRuntime().getModule("Rubylet").getConstant("TRANSFER_ENCODING"),
                               Block.NULL_BLOCK);
        if (!value.isNil() && value.toString().equals("chunked")) {
            body = context.getRuntime()
                    .getModule("Rubylet").getClass("DechunkingBody")
                    .newInstance(context, body, Block.NULL_BLOCK);
        }
        writeBody(context, body);

        if (body.respondsTo("close")) {
            try {
                body.callMethod(context, "close");
            } catch (Exception e) {
                // ignore
            }
        }
    }
    
    public void flush() throws IOException {
        resp.flushBuffer();
    }

    public void setHeaders(ServletResponse resp, int status, RubyHash headers) {
        setHeaders((HttpServletResponse) resp, status, headers);
    }

    public void setHeaders(final HttpServletResponse resp, int status, RubyHash headers) {
        resp.setStatus(status);
    
        headers.visitAll(new Visitor() {
            @Override
            public void visit(IRubyObject name, IRubyObject value) {
                resp.setHeader(name.asJavaString(), value.asJavaString());
            }
        });
    }
    
    private static class Callback implements BlockCallback {
        
        private final OutputStream stream;
        
        private final boolean flush;
        
        public Callback(HttpServletResponse resp, boolean flush) throws IOException {
            this.stream = resp.getOutputStream();
            this.flush = flush;
        }

        @Override
        public IRubyObject call(ThreadContext context, IRubyObject[] args, Block block) {
            final RubyString part = args[0].asString();
            try {
                stream.write(part.getBytes());
                if (flush) { stream.flush(); }
            } catch (IOException e) {
                throw context.getRuntime().newIOErrorFromException(e);
            }
            return context.nil;
        }
        
    }
    
    public void writeBody(ThreadContext context, IRubyObject body) throws IOException {
        body.callMethod(context,
                        "each",
                        ARGS_NONE,
                        CallBlock.newCallClosure(self,
                                                 imClass,
                                                 Arity.ONE_ARGUMENT,
                                                 new Callback(resp, false),
                                                 context));
    }

    /**
     * Write each part in {@code body}, flushing the output stream after
     * each part.
     * 
     * @param context
     * @param body
     * @throws IOException
     */
    public void writeBodyFlush(ThreadContext context, IRubyObject body) throws IOException {
        body.callMethod(context,
                        "each",
                        ARGS_NONE,
                        CallBlock.newCallClosure(self,
                                                 imClass,
                                                 Arity.ONE_ARGUMENT,
                                                 new Callback(resp, true),
                                                 context));
    }

}
