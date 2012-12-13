package com.commongroundpublishing.rubylet;

public class Util {
    
    public static <T> T loadInstance(String className, Class<T> klass) {
        try {
            final Object o = Class.forName(className).newInstance();
            return klass.cast(o);
        } catch (ClassNotFoundException e) {
            throw new IllegalStateException(e);
        } catch (InstantiationException e) {
            throw new IllegalStateException(e);
        } catch (IllegalAccessException e) {
            throw new IllegalStateException(e);
        }
    }

    public static final <A> A assertNotNull(A obj) {
        if (obj == null) {
            throw new IllegalStateException("not initialized");
        }
        
        return obj;
    }

}
