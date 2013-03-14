package rubylet.rack;

import org.jruby.Ruby;
import org.jruby.runtime.load.BasicLibraryService;

import rubylet.StaticFileFilter;

public class ExtService implements BasicLibraryService {

    public boolean basicLoad(Ruby runtime) {
        StaticFileFilter.create(runtime);
        Hash.create(runtime);
        Environment.create(runtime);
        Servlet.create(runtime);
        AsyncCallback.create(runtime);
        return true;
    }

}