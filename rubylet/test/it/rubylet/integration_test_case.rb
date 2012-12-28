require 'jruby/vm'
require 'mechanize'
require 'mini_aether'

MiniAether.setup do
  jar 'org.eclipse.jetty:jetty-servlet:8.1.7.v20120910'
end

module Rubylet
  module IntegrationTestCase
    def self.included(mod)
      "extending #{mod}"
      mod.extend ClassMethods
    end

    def port
      self.class.port
    end

    def get(uri, *args)
      agent.get("http://localhost:#{port}/#{uri}", *args)
    end

    def put(uri, *args)
      agent.put("http://localhost:#{port}/#{uri}", *args)
    end

    def post(uri, *args)
      agent.post("http://localhost:#{port}/#{uri}", *args)
    end

    def agent
      @agent ||= Mechanize.new
    end

    module ClassMethods
      Server = Java::OrgEclipseJettyServer::Server
      ServletContextHandler = Java::OrgEclipseJettyServlet::ServletContextHandler
      ServletHolder = Java::OrgEclipseJettyServlet::ServletHolder
      SelectChannelConnector = Java::OrgEclipseJettyServerNio::SelectChannelConnector
      ExecutorThreadPool = Java::OrgEclipseJettyUtilThread::ExecutorThreadPool
      DefaultServlet = Java::OrgEclipseJettyServlet::DefaultServlet

      attr_writer :app_root
      attr_writer :port

      def app_root
        @app_root || raise("set this in #{self} to point to app root")
      end

      def port
        @port || 9876
      end

      def site
        @site ||= RestClient::Resource.new("http://localhost:#{port}/")
      end

      # In a separate JRuby runtime, create a servlet instance.  In this
      # runtime, start a Jetty server using that servlet.
      def setup_suite
        Dir.chdir(app_root) do
          puts "running bundle install in #{app_root}"
          puts '=' * 20
          system 'bundle install'
          puts '=' * 20
        end
        scope = Java::OrgJrubyEmbed::LocalContextScope::THREADSAFE
        @container = Java::OrgJrubyEmbed::ScriptingContainer.new(scope)
        @container.setCurrentDirectory(app_root)
        @container.getProvider.getRubyInstanceConfig.setUpdateNativeENVEnabled(false)
        servlet = @container.runScriptlet <<-EOF
          ENV['BUNDLE_GEMFILE'] = File.join(Dir.pwd, 'Gemfile')
          ENV['BUNDLE_WITHOUT'] = 'development:test'
          require 'bundler/setup'
          require 'rubylet/servlet'
          Rubylet::Servlet.new
        EOF

        # we have the servlet; now setup jetty
        context = ServletContextHandler.new(ServletContextHandler::SESSIONS)
        context.setContextPath('/')

        holder = ServletHolder.new(servlet)
        holder.setInitParameter 'rubylet.appRoot', app_root
        context.addServlet holder, '/*'

        @server = Server.new(port)
        @server.setHandler(context)
        @server.start
      end

      # Stop the embedded Jetty and JRuby runtime.
      def teardown_suite
        if @server
          @server.stop
          @server.join
        end

        @container.terminate if @container
      end
    end

    def test_simple_get
      resp = get('/')
      assert_equal 200, resp.code.to_i
      assert_match 'tests/index', resp.body
    end

    def test_store_in_session
      resp = get('/session_values/testkey')
      assert_equal 200, resp.code.to_i
      refute_match 'testvalue', resp.body

      # fake 'put' for rails
      resp = post('/session_values/testkey', :value => 'testvalue', :_method => 'put')
      assert_equal 200, resp.code.to_i
      
      resp = get('/session_values/testkey')
      assert_equal 200, resp.code.to_i
      assert_match 'testvalue', resp.body
    end

    def test_log
      resp = get('/tests/log')
      assert_equal 200, resp.code.to_i
    end
  end
end
