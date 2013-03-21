require 'mini_aether'

MiniAether.setup do
  group 'org.apache.tomcat' do
    version '7.0.37' do
      jar 'tomcat-catalina'
      jar 'tomcat-coyote'
    end
  end
end

require 'rubylet/rack'

# well this is dumb...
module Rubylet; module Rack; module Handler; end; end; end

class Rubylet::Rack::Handler::Tomcat
  java_import org.apache.catalina.startup.Tomcat

  attr_reader :options

  def initialize(app, options)
    @app = app
    @options = options

    contextPath = options[:ContextPath] || '/'
    publicRoot = options[:PublicRoot] || 'public'
    baseDir = options[:BaseDir] || 'tmp'

    @server = Tomcat.new
    @server.setPort(options[:Port].to_i)
    @server.setBaseDir(File.expand_path(baseDir))
    
    context = @server.addContext(contextPath, File.expand_path(publicRoot))
    Tomcat.addServlet(context, 'rack', Rubylet::Rack::Servlet.new(@app))
    context.addServletMapping('/*', 'rack')

    # // Add AprLifecycleListener
    # StandardServer server = (StandardServer)tomcat.getServer();
    # AprLifecycleListener listener = new AprLifecycleListener();
    # server.addLifecycleListener(listener);
  end

  def start
    @server.start
  end

  def join
    @server.getServer.await
  end

  def stop
    @server.stop
  end
end
