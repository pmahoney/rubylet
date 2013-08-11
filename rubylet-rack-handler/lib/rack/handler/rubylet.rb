require 'rack/handler'

class Rack::Handler::Rubylet
  DEFAULT_OPTIONS = {
    :ContextPath => '/',
    :UrlPattern => '/*',
    :NoPublic => false,
    :PublicRoot => 'public',
    :Engine => 'jetty'
  }
  
  def self.run(app, options = {})
    options = DEFAULT_OPTIONS.merge(options)

    klass = case (options[:Engine] || 'jetty')
            when 'tomcat'
              require 'rubylet/rack/handler/tomcat'
              Rubylet::Rack::Handler::Tomcat
            when 'jetty'
              require 'rubylet/rack/handler/jetty'
              Rubylet::Rack::Handler::Jetty
            else
              raise ArgumentError, "unknown engine #{options[:Engine]}"
            end

    @server = klass.new(app, options)
    @server.start
    @server.join
  end

  def self.shutdown
    @server.stop if @server
  end

  def self.valid_options
    {
      'ContextPath=PATH' =>
      "The context path at which to serve the app (default '#{DEFAULT[:ContextPath]}')",

      'UrlPattern=PAT' =>
      "The url pattern matching urls serviced by the app (default '#{DEFAULT[:UrlPatter]}')",

      'Threads=NUM' =>
      'Number of threads in the threadpool (default unlimited)',

      'NoPublic' =>
      'Set to disable static file serving (default is to serve)',

      'PublicRoot=PATH' =>
      "Path to static files (default '#{DEFAULT[:PublicRoot]})",

      'Engine=ENGINE' =>
      "The servlet engine to use, jetty or tomcat (default #{DEFAULT[:Engine]})"
    }
  end
end

Rack::Handler.register(:rubylet, Rack::Handler::Rubylet)
