package rubylet.rack;

import org.jruby.Ruby;
import org.jruby.runtime.load.BasicLibraryService;

public class ExtService implements BasicLibraryService {

    public boolean basicLoad(Ruby runtime) {
        Hash.create(runtime);
        Environment.create(runtime);
        Servlet.create(runtime);
        AsyncCallback.create(runtime);
        return true;
    }

}