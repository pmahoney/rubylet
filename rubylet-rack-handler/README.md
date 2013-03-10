A Rack handler for JRuby using Rubylet and Jetty.

    $ cat hello.ru
    run proc {
      [200, {'Content-Type' => 'text/plain'}, ['Hello, World']]
    }

    $ jruby -G -S rackup -s rubylet/jetty hello.ru

By default, will serve static files from the `public` directory
directly from Jetty, bypassing the Ruby stack.