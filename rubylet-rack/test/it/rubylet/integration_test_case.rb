require 'jruby/vm'
require 'mechanize'
require 'mini_aether'
require 'socket'

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

        Dir.chdir(app_root) do
          gemfile = File.expand_path('Gemfile')
          gemfile_lock = gemfile + '.lock'
          # bundle install if necessary
          if !File.exists?(gemfile) || (File.mtime(gemfile) > File.mtime(gemfile_lock))
            puts "----- bundle install"
            system('bundle install --quiet')
            $?.success? || raise("Error running 'bundle install' in #{Dir.pwd}")
          end

          env = {
            'BUNDLE_GEMFILE' => gemfile,
            'BUNDLE_WITHOUT' => 'development:test',
            'RUBY_OPT' => nil
          }
          command = ['jruby', '-X-C', '-G', '-S',
                     'rackup',
                     '-p', port.to_s,
                     '-s', 'Rubylet',
                     '-O', "ContextPath=#{params[:context_path]}",
                     '-O', "UrlPattern=#{params[:url_pattern]}"]
          puts command.join(' ')
          @rackup = Process.spawn(env, *command)
          @rackup || raise("Error starting integration test server")

          # poll until server is listening
          start = Time.now
          begin
            s = Socket.new Socket::AF_INET, Socket::SOCK_STREAM
            addr = Socket.pack_sockaddr_in(port, 'localhost')
            s.connect addr
            puts "server started"
          rescue => e
            elapsed = (Time.now - start).to_i
            raise "timeout waiting for server to start" if elapsed > 600
            puts "waiting for server to start... (#{elapsed}s)"
            sleep 5
            retry
          end
        end
      end

      def teardown_suite
        if @rackup
          begin
            Process.kill('INT', @rackup)
          rescue Errno::ECHILD, Errno::ESRCH
            # maybe it already exited?
          end

          begin
            puts "waiting for server to exit..."
            Process.wait
            puts "server exited"
          rescue Errno::ECHILD
            # already exited
          end
        end
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
