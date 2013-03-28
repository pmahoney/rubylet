Rubylet [![Build Status][travis-img]][travis-ci]
=======

[travis-img]: https://api.travis-ci.org/pmahoney/rubylet.png
[travis-ci]: https://travis-ci.org/pmahoney/rubylet

A collection of Ruby and Java code to support running Rack
applications (Rails, Sinatra, others) inside Java Servlet containers
such as Jetty and Tomcat.

Why Use It?
----------

This is an experimental work-in-progress and not recommended for
production use.

That said, some goals are:

* Support for `throw :async`, the not-quite-standard Rack asynchronous
  api, when using a Servlet container supporting the Servlet 3
  API. (See [Asynchronous responses in
  Rack](http://polycrystal.org/2012/04/15/asynchronous_responses_in_rack.html)).

* Lower per-request overhead compared to JRuby-Rack and others (much
  of the core is written in Java to help with this goal).  A benchmark
  of a trivial "hello world" app with 10k request warmup followed by
  60 seconds of requests at one per second:

  ![Simple benchmark][http://polycrystal.org/~pat/scratch/rubylet-bench1.png]

Note the performance difference compared to Trinidad (JRuby-Rack) is
negligible for a typical Rails app where a given page load takes more
than a few milliseconds.

rubylet-rack
------------

An implementation of the Java Servlet API that forwards to a
contained Rack application as an alternative to
[JRuby-Rack](https://github.com/jruby/jruby-rack).

Supports Rack asynchronous responses initiated with `throw
:async`.

```ruby
    # Java Servlet classes must be available before loading 'rubylet/rack'

    require 'rubylet/rack'

    app = build_my_rack_application()
    servlet = Rubylet::Rack::Servlet.new(app)

    # hand the servlet off to a Java Servlet container
```


rubylet-rack-handler
-------------------

A simple `Rack::Handler` using `rubylet-rack` and
[Jetty](http://eclipse.org/jetty) as the servlet container. Meant for
testing and development purposes only.

With a standard `config.ru`, and a `public` folder, the following will
load the rack application and serve static files directly from Jetty:

    $ rackup -s rubylet

Experimental Tomcat support:

    $ rackup -s rubylet -O Engine=tomcat

rubylet-ee
----------

A Java wrapper around `rubylet-rack` that can be deployed in a WAR file to
a Java EE server.

* Works in WAR files
  * with JRuby and dependent gems packaged into the WAR
  * with pointers to external JRuby and external Ruby application directories

* Only supports threadsafe Ruby applications (does not maintain a pool
  of runtimes to emulate single-threaded app)

* Supports hot (zero downtime) redeploy by monitorin `tmp/restart.txt`

* Supports
  * Rack-based web applications (via `Rubylet::Servlet`)
  * Direct ruby implementations of Java Servlet API

See [rubylet-ee README](https://github.com/commonground/rubylet/tree/master/rubylet-ee)
for more details.

rubylet-tasks
-------------

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
