require 'jruby/vm'
require 'mechanize'
require 'mini_aether'
require 'socket'

require 'rubylet/class_lifecycle'
require 'rubylet/parameterized'

$CLASSPATH << File.expand_path('../../', __FILE__)
MiniAether.setup do
  jar 'org.eclipse.jetty:jetty-servlet:8.1.7.v20120910'
  jar 'ch.qos.logback:logback-classic:1.0.9'
end

module Rubylet
  module IntegrationTestCase
    def self.included(mod)
      mod.extend ClassLifecycle
      mod.extend ClassMethods
      mod.extend Parameterized

      mod.parameterize(:context_path => ['/', '/test_app'],
                       :url_pattern => ['/*', '/sub_path/*'],
                       :port => [9876])
    end

    def uri(path)
      # assume url_pattern is <something>/*
      pattern = if url_pattern =~ /^(.*)\/\*/
                  $1
                else
                  ''
                end
      File.join("http://localhost:#{port}",
                context_path,
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

      attr_reader :agent
      attr_writer :app_root
      attr_writer :port

      def app_root(klass = self)
        if klass.eql?(Object)
          raise("set this in #{self} to point to app root")
        else
          klass.instance_variable_get(:@app_root) || app_root(klass.superclass)
        end
      end

      # def to_s
      #   "#{File.basename(app_root)} with #{context_path}, #{url_pattern}"
      # end

      def site
        @site ||= RestClient::Resource.new("http://localhost:#{port}/")
      end

      # In a separate JRuby process, start a server.
      def before_class
        @agent = Mechanize.new

        Dir.chdir(app_root) do
          gemfile = File.expand_path('Gemfile')
          gemfile_lock = gemfile + '.lock'

          env = {
            'BUNDLE_GEMFILE' => gemfile,
            'BUNDLE_WITHOUT' => 'development:test',
            'RUBYOPT' => nil
          }

          # bundle install if necessary
          if !File.exists?(gemfile_lock) || (File.mtime(gemfile) > File.mtime(gemfile_lock))
            puts "----- bundle install"
            system(env, 'bundle install')
            $?.success? || raise("Error running 'bundle install' in #{Dir.pwd}")
          end

          command = ['jruby', '-X-C', '-G', '-S',
                     'rackup',
                     '-p', port.to_s,
                     '-s', 'Rubylet',
                     '-O', "ContextPath=#{context_path}",
                     '-O', "UrlPattern=#{url_pattern}"]
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

      def after_class
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
