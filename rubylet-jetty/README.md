A Rack handler for JRuby using Rubylet and Jetty.

    $ cat hello.ru
    run proc {
      [200, {'Content-Type' => 'text/plain'}, ['Hello, World']]
    }

    $ jruby -G -Xcompile.invokedynamic=true -Xinvokedynamic.all=true -S rackup -s rubylet/jetty -O StaticUrls=stylesheets,javascripts hello.ru

Can serve static files directly from Jetty, bypassing the Ruby stack.