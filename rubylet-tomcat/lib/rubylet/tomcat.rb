require 'mini_aether'

MiniAether.setup do
  group 'org.apache.tomcat' do
    version '7.0.37' do
      jar 'tomcat-catalina'
      jar 'tomcat-coyote'
    end
  end
end

require 'rack/handler'
require 'rubylet/servlet'
require 'rubylet/static_file_filter'

module Rubylet
  class Tomcat
    java_import org.apache.catalina.startup.Tomcat

    # Create and run a global server
    def self.run(app, options)
      @server = new(app, options)
      @server.start
      @server.await
    end

    # Shutdown the global server
    def self.shutdown
      @server.stop
    end

    def self.valid_options
      {
        'ContextPath=PATH' =>
          'The context path at which to serve the app (default "/")',
        'Threads=NUM' =>
          'Number of threads in the threadpool (default unlimited)',
        'BaseDir' =>
          'Base dir for tomcat temp files (default "tmp")',
        'NoPublic' =>
          'Set to disable static file serving (default is to serve)',
        'PublicRoot=PATH' =>
          'Path to static files (default "public")'
      }
    end

    attr_reader :options

    def initialize(app, options)
      @app = app
      @options = options

      contextPath = options[:ContextPath] || '/'
      publicRoot  = options[:PublicRoot] || 'public'
      baseDir     = options[:BaseDir] || 'tmp'

      @server = Tomcat.new
      @server.setPort(options[:Port].to_i)
      @server.setBaseDir(File.expand_path(baseDir))
 
      context = @server.addContext(contextPath, File.expand_path(publicRoot))
      Tomcat.addServlet(context, 'rack', Rubylet::Servlet.new(@app))
      context.addServletMapping('/*', 'rack')

      # // Add AprLifecycleListener
      # StandardServer server = (StandardServer)tomcat.getServer();
      # AprLifecycleListener listener = new AprLifecycleListener();
      # server.addLifecycleListener(listener);
    end

    def start
      @server.start
    end

    def await
      @server.getServer.await
    end

    def stop
      @server.stop
    end
  end
end

