package com.commongroundpublishing.rubylet.jruby;

import org.jruby.embed.ScriptingContainer;


public class ScriptingContainerFactory {
    
    public ScriptingContainer makeContainer(RubyConfig config) {
        // Required global setting for when JRuby fakes up Kernel.system('ruby')
        // calls.
        // Since this is global, other JRuby servlets in this servlet container
        // are affected...
        //
        // TODO: move to a better location in the code?  remove?
        if (config.getJrubyHome() != null) {
            System.setProperty("jruby.home", config.getJrubyHome());
        }
        
        final ScriptingContainer container = new ScriptingContainer(config.getScope());
        
        container.setCompileMode(config.getCompileMode());
        container.setHomeDirectory(config.getJrubyHome());
        container.setCompatVersion(config.getCompatVersion());
        container.setCurrentDirectory(config.getAppRoot());
        // don't propagate ENV to global JVM level
        container.getProvider().getRubyInstanceConfig().setUpdateNativeENVEnabled(false);
        
        return container;
    }

}
