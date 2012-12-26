rubylet-ee
==========

A Java wrapper around `rubylet` that can be deployed in a WAR file to
a Java EE server.

* Supports WAR files with JRuby and dependent gems packaged into the WAR

* Supports WAR files pointing to external JRuby and external Ruby application

* Only supports threadsafe Ruby applications (does not maintain a pool
  of runtimes to emulate single-threaded app)

* Supports hot (zero downtime) redeploy by monitorin `tmp/restart.txt`

* Supports Rack-based web applications

* Supports direct ruby implementations of Java Servlet API

Configuration
-------------

Rubylet-ee is configured by parameters in the `web.xml` descriptor.
Context parameters apply to all rubylet-ee instances (servlet,
listeners, etc.) defined in the descriptor.  Init parameters apply
only to one specific instance.

* `rubylet.jrubyHome` Absolute path to a JRuby installation

* `rubylet.env.<NAME>` Environment variables set during initialization
of a JRuby runtime.

* `rubylet.runtime` The name of the runtime to use.  Defaults to
`default`.  Runtimes may be shared by multiple servlet instances.

* `rubylet.localContextScope` The local context scope of a new
runtime. Default `THREADSAFE`.

* `rubylet.compileMode` The compile mode of a new runtime.  Default
`JIT`.

* `rubylet.compatVersion` The compat version of a new runtime.
Default `RUBY1_9`.

* `rubylet.appRoot` The root of the ruby application.  Defaults to
`WEB-INF/classes`, but may be an absolute path to an application
stored externally

* `rubylet.boot` Ruby file to load when initializing a runtime.
Default none.  Must ensure that the ruby class in
`rubylet.servletClass` is loaded.  Default none.

* `rubylet.servletClass` For Servlets, the ruby class to be
instantiated.  Default `Rubylet::Servlet` (no `rubylet.boot` is
required in this case).

* `rubylet.watchFile` A file relative to `appRoot` that, when its
modification time changes, will trigger a restart of the runtime.

* `rubylet.bundleExec` The string `true` or `false`; if the app should
be started with `bundle exec`.  Default `false`.

* `rubylet.bundleGemfile` The gemfile to load if `bundle exec` is
`true`.  Default `Gemfile`.

* `rubylet.bundleWithout` The groups to exclude if `bundle exec` is
true.  Default `development:test`.

Rack::Servlet Configuration
---------------------------

Additional parameters configure `Rack::Servlet` when using this
servlet to load a Rack application.

* `rubylet.rackupFile` The rackup file to load.  Default `config.ru`.

* `rubylet.servletPath` For Rails apps, the path at which requests
will be directed to this servlet.  If a servlet is configured in
`web.xml` to server a URL pattern other than `/*`, then
`rubylet.servletPath` should be set to match so that
ActionController::Base.config.relative_url_root may be set correctly.

Example: JRuby and gems packed into WAR file
--------------------------------------------

See `examples/demo_app` for full examples.

Create a maven project to build a WAR file.

    <project>
      ...
      <packaging>war</packaging>

Declare dependencies on `org.jruby:jruby-complete` and
`com.commongroundpublishing:rubylet-ee`.

One way to package everything into the WAR file is to use the
[Torquebox Rubygems Maven Proxy
Repository](http://rubygems-proxy.torquebox.org/)

      <repositories>
        <repository>
          <id>rubygems-releases</id>
          <url>http://rubygems-proxy.torquebox.org/releases</url>
        </repository>
      </repositories>

Then declare gems dependencies in `pom.xml` on rubygems `bundler`,
`rack`, `rubylet` and anything else required.

        <dependency>
          <groupId>rubygems</groupId>
          <artifactId>rubylet</artifactId>
          <version>[0,)</version>
          <type>gem</type>
        </dependency>

Configure `gem-maven-plugin` to unpack rubygem dependencies into
`target/rubygems` (done by default with the `initialize` goal).

          <plugin>
            <groupId>de.saumya.mojo</groupId>
            <artifactId>gem-maven-plugin</artifactId>
            <version>0.28.6</version>
            <executions>
              <execution>
               <goals>
                 <goal>initialize</goal>
               </goals>
             </execution>
           </executions>
         </plugin>

Configure `maven-war-plugin` to copy rubytems into the
`WEB-INF/rubygems`.

         <plugin>
           <groupId>org.apache.maven.plugins</groupId>
           <artifactId>maven-war-plugin</artifactId>
           <executions>
             <execution>
               <id>war-internal</id>
               <configuration>
                 <webResources>
                   <resource>
                     <directory>${project.build.directory}/rubygems</directory>
                     <targetPath>WEB-INF/rubygems</targetPath>
                   </resource>
                 </webResources>
               </configuration>
              <goals>
                <goal>war</goal>
              </goals>
            </executions>
          </plugin>

Example: JRuby, gems, and Ruby app external to WAR file
-------------------------------------------------------

See `examples/demo_app/src/main/webapp/WEB-INF/external-jruby-web.xml`
for web.xml.

Create a maven project to build a WAR file.

    <project>
      ...
      <packaging>war</packaging>

Declare dependencies on `com.commongroundpublishing:rubylet-ee`.

In the `web.xml`, configure as context parameters `rubylet.jrubyHome`
and `rubylet.appRoot`.

    <context-param>
      <param-name>rubylet.jrubyHome</param-name>
      <param-value>/absolute/path/to/jruby-1.7.1</param-value>
    </context-param>
    <context-param>
      <param-name>rubylet.appRoot</param-name>
      <param-value>/absolute/path/to/ruby_app</param-value>
    </context-param>

Configure an instance of `RestartableServlet`.

    <servlet>
      <servlet-name>rubylet-servlet</servlet-name>
      <servlet-class>com.commongroundpublishing.rubylet.RestartableServlet</servlet-class>
      <load-on-startup>1</load-on-startup>
    </servlet>
    <servlet-mapping>
      <servlet-name>rubylet-servlet</servlet-name>
      <url-pattern>/*</url-pattern>
    </servlet-mapping>
