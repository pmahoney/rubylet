require 'mini_aether'

MiniAether.setup do
  jetty_version = '8.1.8.v20121106'

  jar "org.eclipse.jetty:jetty-servlet:#{jetty_version}"

  # slf4j_version = '1.7.2'
  # jar "org.slf4j:slf4j-api:#{slf4j_version}"
  # jar "org.slf4j:slf4j-simple:#{slf4j_version}"
end

require 'rubylet/rack'

module Rubylet; module Rack; module Handler; end; end; end

class Rubylet::Rack::Handler::Jetty
  Server                 = Java::OrgEclipseJettyServer::Server
  ServletContextHandler  = Java::OrgEclipseJettyServlet::ServletContextHandler
  ServletHolder          = Java::OrgEclipseJettyServlet::ServletHolder
  FilterHolder           = Java::OrgEclipseJettyServlet::FilterHolder
  SelectChannelConnector = Java::OrgEclipseJettyServerNio::SelectChannelConnector
  ExecutorThreadPool     = Java::OrgEclipseJettyUtilThread::ExecutorThreadPool
  DefaultServlet         = Java::OrgEclipseJettyServlet::DefaultServlet
  DispatcherType         = Java::JavaxServlet::DispatcherType

  attr_reader :context_path, :url_pattern, :threads, :no_public, :public_root, :port, :host

  def initialize(app, options)
    @context_path = options[:ContextPath]
    @url_pattern  = options[:UrlPattern]
    @threads      = options[:Threads] && options[:Threads].to_i
    @no_public    = options[:NoPublic]
    @public_root  = options[:PublicRoot]
    @port         = options[:Port].to_i
    @host         = options[:Host]

    context = ServletContextHandler.new(ServletContextHandler::SESSIONS)
    context.setContextPath(context_path)

    # order matters here; rubylet must be added *after* the
    # default servlet so that rubylet has priority
    add_public(context) unless no_public

    context.addServlet ServletHolder.new(make_servlet(app)), url_pattern
      
    @server = make_server
    @server.setHandler(context)
  end

  def start
    @server.start
  end

  def join
    @server.join
  end

  def stop
    @server.stop
  end

  private

  def make_servlet(app)
    case app
    when Java::JavaxServlet::Servlet
      app
    else
      Rubylet::Rack::Servlet.new(app)
    end
  end

  def make_server
    Server.new.tap do |server|
      SelectChannelConnector.new.tap do |connector|
        connector.setPort port
        connector.setHost host
        server.addConnector connector
      end

      if threads
        server.setThreadPool ExecutorThreadPool.new(threads, threads, 0)
      end
    end
  end

  # Add a filter that will serve static files if they exist, or
  # continue down the chain (to the rack app).
  #
  # Installs a default servlet at '/*', so must be called before
  # the rack app's servlet is added so rack will take priority.
  def add_public(context)
    FilterHolder.new(Rubylet::StaticFileFilter.new).tap do |holder|
      holder.setInitParameter 'resourceBase', public_root
      types = [DispatcherType::ASYNC,
               DispatcherType::ERROR,
               DispatcherType::FORWARD,
               DispatcherType::INCLUDE,
               DispatcherType::REQUEST]
      dispatches = Java::JavaUtil::EnumSet.of(*types)
      context.addFilter holder, url_pattern, dispatches
    end

    ServletHolder.new('default', DefaultServlet.new).tap do |holder|
      {
        'acceptRanges'    => true,
        'welcomeServlets' => false,
        'gzip'            => true,
        'resourceBase'    => public_root
      }.each { |k,v| holder.setInitParameter(k, v.to_s) }
      context.addServlet holder, '/*'
    end
  end
end
