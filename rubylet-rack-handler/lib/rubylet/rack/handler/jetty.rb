require 'mini_aether'

MiniAether.setup do
  jetty_version = '8.1.8.v20121106'

  jar "org.eclipse.jetty:jetty-servlet:#{jetty_version}"

  # slf4j_version = '1.7.2'
  # jar "org.slf4j:slf4j-api:#{slf4j_version}"
  # jar "org.slf4j:slf4j-simple:#{slf4j_version}"
end

require 'rubylet/rack'
require 'rubylet/static_file_filter'

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

  attr_reader :options

  def initialize(app, options)
    @app = app
    @options = options
    @contextPath = options[:ContextPath] || '/'

    @context = ServletContextHandler.new(ServletContextHandler::SESSIONS)
    @context.setContextPath(@contextPath)
    
    add_public unless options[:NoPublic]
    add_rack_app

    @server = make_server
    @server.setHandler(@context)
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

  # order matters here; rubylet must be added *after* the
  # default servlet so that rubylet has priority
  def add_rack_app
    ServletHolder.new(Rubylet::Rack::Servlet.new(@app)).tap do |holder|
      @context.addServlet holder, '/*'
    end
  end

  def make_server
    server = Server.new

    connector = SelectChannelConnector.new
    connector.setPort options[:Port].to_i
    connector.setHost options[:Host]
    server.addConnector connector

    if options[:Threads]
      pool = ExecutorThreadPool.new(options[:Threads].to_i,
                                    options[:Threads].to_i,
                                    0)
      server.setThreadPool pool
    end

    server
  end

  # Add a filter that will serve static files if they exist, or
  # continue down the chain (to the rack app).
  #
  # Installs a default servlet at '/*', so must be called before
  # the rack app's servlet is added so rack will take priority.
  def add_public
    public_root = options[:PublicRoot] || 'public'

    FilterHolder.new(Rubylet::StaticFileFilter.new).tap do |holder|
      holder.setInitParameter 'resourceBase', public_root
      types = [DispatcherType::ASYNC,
               DispatcherType::ERROR,
               DispatcherType::FORWARD,
               DispatcherType::INCLUDE,
               DispatcherType::REQUEST]
      dispatches = Java::JavaUtil::EnumSet.of(*types)
      @context.addFilter holder, '/*', dispatches
    end

    ServletHolder.new('default', DefaultServlet.new).tap do |holder|
      {
        'acceptRanges' => true,
        'welcomeServlets' => false,
        'gzip' => true,
        'resourceBase' => public_root
      }.each { |k,v| holder.setInitParameter(k, v.to_s) }
      @context.addServlet holder, '/*'
    end
  end
end
