package rubylet;

import static org.jruby.runtime.Visibility.PRIVATE;

import java.lang.reflect.Field;
import java.lang.reflect.Method;

import org.jruby.Ruby;
import org.jruby.RubyClass;
import org.jruby.RubyHash;
import org.jruby.RubyModule;
import org.jruby.anno.JRubyClass;
import org.jruby.anno.JRubyMethod;
import org.jruby.runtime.Block;
import org.jruby.runtime.ObjectAllocator;
import org.jruby.runtime.ThreadContext;
import org.jruby.runtime.builtin.IRubyObject;

/**
 * Extend JRuby's RubyHash with a faster {@code dup} and a means to iterate
 * through then entry set.
 * 
 * @author Patrick Mahoney <pat@polycrystal.org>
 */
@JRubyClass(name = "Rubylet::Hash")
public class Hash extends RubyHash {

    private static final long serialVersionUID = 1L;
    
    private static final ObjectAllocator ALLOCATOR = new ObjectAllocator() {
        public IRubyObject allocate(Ruby runtime, RubyClass klass) {
            return new Hash(runtime, klass);
        }
    };

    public static void create(Ruby runtime) {
        final RubyModule rubylet = runtime.defineModule("Rubylet");
        final RubyModule hash = rubylet.defineClassUnder("Hash", runtime.getHash(), ALLOCATOR);
        hash.defineAnnotatedMethods(Hash.class);
    }

    private static final Method RubyHash_internalCopyTable;
    static {
        try {
            RubyHash_internalCopyTable = RubyHash.class.getDeclaredMethod("internalCopyTable", RubyHashEntry.class);
            RubyHash_internalCopyTable.setAccessible(true);
        } catch (Exception e) {
            throw new RuntimeException("can't obtain handle to private method 'internalCopyTable'", e);
        }
    }

    private static final Field RubyHash_head;
    static {
        try {
            RubyHash_head = RubyHash.class.getDeclaredField("head");
            RubyHash_head.setAccessible(true);
        } catch (Exception e) {
            throw new RuntimeException("can't obtain handle to private field 'head'", e);
        }
    }

    private static final Field RubyHash_table;
    static {
        try {
            RubyHash_table = RubyHash.class.getDeclaredField("table");
            RubyHash_table.setAccessible(true);
        } catch (Exception e) {
            throw new RuntimeException("can't obtain handle to private field 'table'", e);
        }
    }

    public Hash(Ruby runtime, RubyClass klass) {
        super(runtime, klass);
    }

    /**
     * Iterate through the entry set, yield each key, value pair to the
     * block, and set each value to the value of the block.
     */
    @JRubyMethod(name = "update_values")
    public RubyHash updateValues(final ThreadContext context, final Block block) {
        for (Object _entry : directEntrySet()) {
            final RubyHashEntry entry = (RubyHashEntry) _entry;
            entry.setValue(block.yieldSpecific(context,
                                               (IRubyObject) entry.getKey(),
                                               (IRubyObject) entry.getValue()));
        }

        return this;
    }

    /**
     * A faster copy of the {@code other} hash.  Does not maintain insertion order.
     */
    @JRubyMethod(name = "initialize_copy", required = 1, visibility = PRIVATE)
    @Override
    public RubyHash initialize_copy(ThreadContext context, IRubyObject other) {
        final RubyHash otherHash = other.convertToHash();
        
        // insertion order gets blown away, but so what
        setTable(internalCopyTable(otherHash, getHead()));
        size = otherHash.size();
        
        return this;
    }
    
    // expose some RubyHash internals
    
    private static RubyHashEntry[] internalCopyTable(RubyHash obj, RubyHashEntry dest) {
        try {
            return (RubyHashEntry[]) RubyHash_internalCopyTable.invoke(obj, dest);
        } catch (Exception e) {
            throw new RuntimeException("error invoking private method 'internalCopyTable'", e);
        }
    }
    
    private RubyHashEntry getHead() {
        try {
            return (RubyHashEntry) RubyHash_head.get(this);
        } catch (Exception e) {
            throw new RuntimeException("can't read private field 'head'", e);
        }
    }
    
    private void setTable(RubyHashEntry[] table) {
        try {
            RubyHash_table.set(this, table);
        } catch (Exception e) {
            throw new RuntimeException("can't write private field 'table'", e);
        }
    }

}
