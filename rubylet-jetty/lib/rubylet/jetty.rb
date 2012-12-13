require 'mini_aether'
MiniAether.setup do
  jar 'org.eclipse.jetty:jetty-servlet:8.1.7.v20120910'
end

require 'rack/handler'
require 'rubylet/servlet'

module Rubylet
  class Jetty
    Server = Java::OrgEclipseJettyServer::Server
    ServletContextHandler = Java::OrgEclipseJettyServlet::ServletContextHandler
    ServletHolder = Java::OrgEclipseJettyServlet::ServletHolder
    SelectChannelConnector = Java::OrgEclipseJettyServerNio::SelectChannelConnector
    ExecutorThreadPool = Java::OrgEclipseJettyUtilThread::ExecutorThreadPool
    DefaultServlet = Java::OrgEclipseJettyServlet::DefaultServlet

    class << self
      def run(app, options)
        @server = Server.new

        connector = SelectChannelConnector.new
        connector.setPort options[:Port].to_i
        connector.setHost options[:Host]
        @server.addConnector connector

        if options[:Threads]
          pool = ExecutorThreadPool.new(options[:Threads].to_i,
                                        options[:Threads].to_i,
                                        0)
          @server.setThreadPool pool
        end
        
        context = ServletContextHandler.new(ServletContextHandler::SESSIONS)
        context.setContextPath('/')

        ServletHolder.new(Rubylet::Servlet.new).tap do |holder|
          holder.setInitParameter 'jrubyHome', jruby_home
          holder.setInitParameter 'appRoot', File.dirname(options[:config])
          holder.setInitParameter 'rackupFile', options[:config]
          context.addServlet holder, '/*'
        end

        if options[:StaticUrls]
          ServletHolder.new(DefaultServlet.new).tap do |holder|
            {
              'acceptRanges' => true,
              'welcomeServlets' => false,
              'gzip' => true,
              'resourceBase' => options[:StaticRoot] || 'public'
            }.each { |k,v| holder.setInitParameter(k, v.to_s) }
            
            options[:StaticUrls].split(',').each do |prefix|
              prefix = "/#{prefix}" unless prefix.start_with? '/'
              context.addServlet holder, "#{prefix}/*"
            end
          end
        end

        @server.setHandler(context)
        @server.start
        @server.join
      end

      def jruby_home
        regex = %r{/lib/ruby/site_ruby.*}
        $LOAD_PATH.find { |p| p =~ regex }.gsub(regex, '')
      end

      def shutdown
        @server.stop
      end

      def valid_options
        {
          'Threads=NUM' =>
          'Number of threads in the threadpool (default unlimited)',
          'StaticUrls=PREFIXES' =>
          'Comma separated list of URL prefixes to static files, e.g. "/stylesheets"',
          'StaticRoot=PATH' =>
          'Path to static files (default "public")'
        }
      end
    end
  end
end

