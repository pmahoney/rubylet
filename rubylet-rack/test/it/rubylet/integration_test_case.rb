require 'jruby/vm'
require 'mechanize'
require 'mini_aether'

$CLASSPATH << File.expand_path('../../', __FILE__)
MiniAether.setup do
  jar 'org.eclipse.jetty:jetty-servlet:8.1.7.v20120910'
  jar 'ch.qos.logback:logback-classic:1.0.9'
end

module Rubylet
  module IntegrationTestCase
    def self.included(mod)
      mod.extend ClassMethods
    end

    def port
      self.class.port
    end

    def params
      self.class.params
    end

    def uri(path)
      # assume url_pattern is <something>/*
      pattern = if params[:url_pattern] =~ /^(.*)\/\*/
                  $1
                else
                  ''
                end
      File.join("http://localhost:#{port}",
                params[:context_path],
                pattern,
                path)
    end

    def get(path, *args)
      resp = agent.get(uri(path))

      if resp.respond_to?(:at) && elem = resp.at('head meta[name="csrf-param"]')
        @csrf_param = elem['content']
      end

      if resp.respond_to?(:at) && elem = resp.at('head meta[name="csrf-token"]')
        @csrf_token = elem['content']
      end

      resp
    end

    def put(path, *args)
      agent.put(uri(path), *args)
    end

    def post(path, query, headers={})
      if @csrf_param && @csrf_token
        query[@csrf_param] = @csrf_token
      end
      agent.post(uri(path), query, headers)
    end

    def agent
      self.class.agent
    end

    module ClassMethods
      Server = Java::OrgEclipseJettyServer::Server
      ServletContextHandler = Java::OrgEclipseJettyServlet::ServletContextHandler
      ServletHolder = Java::OrgEclipseJettyServlet::ServletHolder
      SelectChannelConnector = Java::OrgEclipseJettyServerNio::SelectChannelConnector
      ExecutorThreadPool = Java::OrgEclipseJettyUtilThread::ExecutorThreadPool
      DefaultServlet = Java::OrgEclipseJettyServlet::DefaultServlet

      def parameters
        {
          :context_path => ['/', '/test_app'],
          :url_pattern => ['/*', '/sub_path/*']
        }
      end

      attr_reader :params
      attr_reader :agent
      attr_writer :app_root
      attr_writer :port

      def app_root
        @app_root || raise("set this in #{self} to point to app root")
      end

      def to_s
        "#{File.basename(app_root)} with #{params}"
      end

      def port
        @port || 9876
      end

      def site
        @site ||= RestClient::Resource.new("http://localhost:#{port}/")
      end

      # In a separate JRuby runtime, create a servlet instance.  In this
      # runtime, start a Jetty server using that servlet.
      def setup_suite(params)
        @params = params
        @agent = Mechanize.new

        scope = Java::OrgJrubyEmbed::LocalContextScope::THREADSAFE
        mode = Java::OrgJruby::RubyInstanceConfig::CompileMode::OFF
        @container = Java::OrgJrubyEmbed::ScriptingContainer.new(scope)
        @container.setCompileMode(mode) # for short lived tests, no-compile is faster
        @container.setCurrentDirectory(app_root)
        @container.getProvider.getRubyInstanceConfig.setUpdateNativeENVEnabled(false)
        servlet = @container.runScriptlet <<-EOF
          ENV['BUNDLE_GEMFILE'] = File.join(Dir.pwd, 'Gemfile')
          if !File.exists?('Gemfile.lock') || (File.mtime('Gemfile') > File.mtime('Gemfile.lock'))
            puts "----- bundle install"
            require 'bundler'
            require 'bundler/cli'
            Bundler::CLI.new([], :quiet => true).invoke(:install)
          end
          ENV['BUNDLE_WITHOUT'] = 'development:test'
          require 'bundler/setup'
          require 'rubylet/rack'
          Rubylet::Rack::Servlet.new
        EOF

        # we have the servlet; now setup jetty
        context = ServletContextHandler.new(ServletContextHandler::SESSIONS)
        context.setContextPath(params[:context_path])

        holder = ServletHolder.new(servlet)
        holder.setInitParameter 'rubylet.appRoot', app_root
        context.addServlet holder, params[:url_pattern]

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
      resp = get('')
      assert_equal 200, resp.code.to_i
      assert_match 'tests/index', resp.body
    end

    def test_large_get
      resp = get('tests/large/10000')
      assert_equal 200, resp.code.to_i
      assert_equal 10000, resp.body.size
    end

    def test_store_in_session
      resp = get('session_values/testkey')
      assert_equal 200, resp.code.to_i
      refute_match 'testvalue', resp.body

      # fake 'put' for rails
      resp = post('session_values/testkey', :value => 'testvalue', :_method => 'put')
      assert_equal 200, resp.code.to_i
      
      resp = get('session_values/testkey')
      assert_equal 200, resp.code.to_i
      assert_match 'testvalue', resp.body
    end

    def test_log
      resp = get('tests/log')
      assert_equal 200, resp.code.to_i
    end
  end
end
