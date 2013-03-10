package rubylet.rack;

import org.jruby.Ruby;
import org.jruby.RubyModule;
import org.jruby.runtime.builtin.IRubyObject;

public class Rubylet {
    
    public static void defineConstant(Ruby runtime, String name, String value) {
        final RubyModule rubylet = runtime.getModule("Rubylet");
        final IRubyObject str = runtime.newString(value)
                .freeze(runtime.getCurrentContext());
        
        rubylet.defineConstant(name, str);
    }

    public static void defineConstant(Ruby runtime, String name) {
        defineConstant(runtime, name, name);
    }

    public static IRubyObject getConstant(Ruby runtime, String name) {
        return runtime.getModule("Rubylet").getConstant(name);
    }

}
