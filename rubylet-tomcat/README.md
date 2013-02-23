rubylet-tomcat (work in progress)
-------------

A Rack handler for JRuby using Rubylet and Tomcat.  Useful for
development and experimentation.  Not for production use.

    $ cat config.ru
    run proc {
      [200, {'Content-Type' => 'text/plain'}, ['Hello, World']]
    }

    $ jruby -G -S rackup -s rubylet/tomcat

Static files are not currently served.
