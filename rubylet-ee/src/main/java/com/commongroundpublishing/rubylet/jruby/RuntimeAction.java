package com.commongroundpublishing.rubylet.jruby;

import org.jruby.embed.ScriptingContainer;

public interface RuntimeAction<T> {
    
    public T run(ScriptingContainer container);

}
