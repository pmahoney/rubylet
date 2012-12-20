package com.commongroundpublishing.rubylet.config;

import java.util.ArrayList;
import java.util.Arrays;
import java.util.Collections;
import java.util.List;
import java.util.Enumeration;

import javax.servlet.ServletContext;

public final class ChainedConfig implements IConfig {
    
    private final List<IConfig> chain;
    
    public ChainedConfig(IConfig...chain) {
        this.chain = Collections.unmodifiableList(Arrays.asList(chain));
    }
    
    public ServletContext getServletContext() {
        return chain.get(0).getServletContext();
    }

    /**
     * For each member of the chain, test if it contains a value
     * for {@code name} and return the first, or null if none
     * have a value.
     */
    public String get(String name) {
        for (IConfig p : chain) {
            final String value = p.get(name);
            if (value != null) {
                return value;
            }
        }
        
        return null;
    }

    /**
     * Keys existing in multiple members of the chain will show up
     * as duplicates.
     */
    public Enumeration<String> getNames() {
        return new ChainedEnumerations(chain);
    }
    
    /**
     * Inefficient, but will suffice for our chains which should at most be
     * size 2.  Keys existing in multiple members of the chain will show up
     * as duplicates.
     * 
     * @author Patrick Mahoney <patrick.mahoney@commongroundpublishing.com>
     */
    private static class ChainedEnumerations implements Enumeration<String> {
            
        private final ArrayList<Enumeration<String>> enums;
            
        public ChainedEnumerations(List<IConfig> chain) {
            enums = new ArrayList<Enumeration<String>>(chain.size());
            for (IConfig p : chain) {
                enums.add(p.getNames());
            }
        }
            
        public boolean hasMoreElements() {
            for (Enumeration<String> e : enums) {
                if (e.hasMoreElements()) {
                    return true;
                }
            }
            return false;
        }

        public String nextElement() {
            for (Enumeration<String> e : enums) {
                if (e.hasMoreElements()) {
                    return e.nextElement();
                }
            }
            return null;
        }
            
    }

}
