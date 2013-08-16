package org.polycrystal.rubylet.config;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertNull;
import static org.junit.Assert.assertTrue;

import java.util.ArrayList;
import java.util.Enumeration;
import java.util.Hashtable;

import javax.servlet.ServletContext;

import org.junit.Test;

public class PrefixedConfigTest {
    
    public static class HashConfig implements IConfig {
        
        Hashtable<String,String> hash = new Hashtable<String,String>();

        public ServletContext getServletContext() {
            return null;
        }

        public String get(String name) {
            return hash.get(name);
        }

        public Enumeration<String> getNames() {
            return hash.keys();
        }
        
        public void set(String name, String value) {
            hash.put(name, value);
        }
        
    }
    
    @Test
    public void filtersOtherConfigByPrefix() {
        HashConfig base = new HashConfig();
        base.set("prefix.value", "value");
        base.set("name", "value");
        base.set("prefix.other", "other");
        base.set("prefix", "nope");
        
        PrefixedConfig config = new PrefixedConfig("prefix.", base);
        
        assertEquals("value", config.get("value"));
        assertEquals("other", config.get("other"));
        assertNull(config.get("prefix.value"));
        assertNull(config.get("name"));
        
        ArrayList<String> names = new ArrayList<String>();
        Enumeration<String> namesEnum = config.getNames();
        while (namesEnum.hasMoreElements()) {
            names.add(namesEnum.nextElement());
        }
        
        assertEquals(2, names.size());
        assertTrue(names.contains("value"));
        assertTrue(names.contains("other"));
    }

}
