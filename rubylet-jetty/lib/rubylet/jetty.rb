require 'mini_aether'
MiniAether.setup do
  jar 'org.eclipse.jetty:jetty-servlet:8.1.7.v20120910'
end

require 'rack/handler'
require 'rubylet/servlet'
require 'rubylet/static_file_filter'

module Rubylet
  class Jetty
    Server = Java::OrgEclipseJettyServer::Server
    ServletContextHandler = Java::OrgEclipseJettyServlet::ServletContextHandler
    ServletHolder = Java::OrgEclipseJettyServlet::ServletHolder
    FilterHolder = Java::OrgEclipseJettyServlet::FilterHolder
    SelectChannelConnector = Java::OrgEclipseJettyServerNio::SelectChannelConnector
    ExecutorThreadPool = Java::OrgEclipseJettyUtilThread::ExecutorThreadPool
    DefaultServlet = Java::OrgEclipseJettyServlet::DefaultServlet
    DispatcherType = Java::JavaxServlet::DispatcherType

    class << self
      # Create and run a global server
      def run(app, options)
        @server = new(app, options)
        @server.start
        @server.join
      end

      # Shutdown the global server
      def shutdown
        @server.stop
      end

      def valid_options
        {
          'Threads=NUM' =>
            'Number of threads in the threadpool (default unlimited)',
          'NoPublic' =>
            'Set to disable static file serving (default is to serve)',
          'PublicRoot=PATH' =>
            'Path to static files (default "public")'
        }
      end
    end

    attr_reader :app, :options

    def initialize(app, options)
      @app = app
      @options = options
      @context = ServletContextHandler.new(ServletContextHandler::SESSIONS)
      @context.setContextPath('/')

      unless options[:NoPublic]
        add_public
      end

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
      ServletHolder.new(Rubylet::Servlet.new).tap do |holder|
        holder.setInitParameter 'rubylet.rackupFile', options[:config]
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
end

