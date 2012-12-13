Rubylet
-------

A collection of Ruby and Java code to support running Rack
applications (Rails, Sinatra, others) inside Java Servlet containers
(Jetty, others).

rubylet
=======

A pure Ruby implementation of the Java Servlet API that forwards to a
contained Rack application as an alternative to
[JRuby-Rack](https://github.com/jruby/jruby-rack).

rubylet-jetty
=============

A simple `Rack::Handler` using `rubylet` and
[Jetty](http://eclipse.org/jetty) as the servlet container. Meant for
testing and development purposes only.

With a standard `config.ru`, and `public/stylesheets` and
`public/javascripts` folders, the following will load the rack
application and serve static files directly from Jetty:

    rackup -s rack/jetty -O StaticUrls=/stylesheets,/javascripts

rubylet-ee
==========

A Java wrapper around `rubylet` that can be deployed in a WAR file to
a Java EE server.

* Currently only supports running an external (not in the WAR file),
  Rack application (i.e. a typical Ruby development tree of files).

* Only supports threadsafe Ruby applications.  Does not maintain a
  pool of JRuby runtimes to emulate single-threaded processes (though
  I'm not opposed to this feature).

* WAR file is very small as it does not contain the Ruby application
  or dependent gems, but JRuby, gems, and the application must be
  installed and managed separately.

* Supports hot (zero downtime) redeploy by monitoring `tmp/restart.txt`.

* Supports direct ruby implementations of the Java Servlet API
  (typical setup will use Rubylet::Servlet to wrap a standard Rack
  application, but this is not required).

* A bit confused and in need of refactoring, documentation, tests.

rubylet-tasks
=============

Some Rake tasks for building a WAR file using `rubylet-ee`.  In the
Rakefile of a Rack application:

    require 'rubylet/war_task'

    Rubylet::WarTask.new do |w|
      w.name = 'test_app'
      w.external_jruby
      w.rubylet do |r|
        # if you cannot add 'rubylet' to the Gemfile, list it here.
        # r.gem 'rubylet', '>= 0'
      end
    end

Then

    $ rake war
    $ <deploy> pkg/test_app.war  # <deploy> is specific to the particular Java Servlet Container

This WAR file will depend on the current JRuby installation and
current app location.  For example, if the app is in `~/dev/test_app`,
that is where the build WAR file will expect to find it.

A running app may be restarted by touching `tmp/restart.txt` and
making an HTTP request to it.  Rubylet will reload a second instance
of the app, and when ready, swap the second instance with the original
for a zero downtime hot redeploy.

    $ touch tmp/restart.txt
    $ curl http://localhost:8080/test_app
    $ tail path/to/servlet_container/log

    INFO:test_app:com.commongroundpublishing.rubylet.jruby.RestartableRuntime@7fa05428: restart triggered
    INFO:test_app:setup bundler with gemfile=Gemfile without=development:test
    INFO:test_app:com.commongroundpublishing.rubylet.jruby.RestartableRuntime@7fa05428: new container org.jruby.embed.ScriptingContainer@75821e76
    INFO:test_app:example: new servlet instance Rubylet::Servlet
    INFO:test_app:example: initialized #<Rubylet::Servlet @app=#<Proc:0x541709cc@config.ru:2>>
    INFO:test_app:destroyed #<Rubylet::Servlet @app=#<Proc:0x1eb07515@config.ru:2>>
    INFO:test_app:com.commongroundpublishing.rubylet.jruby.RestartableRuntime@7fa05428: terminated org.jruby.embed.ScriptingContainer@7e0ac8b

More documentation to come...

TODO:

* Static file handling is a bit of a mess.  May work in Jetty; untested elsewhere.
* Refactor, write more documentation, tests.
