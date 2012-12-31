require 'fileutils'
require 'mini_aether'
require 'rake/tasklib'
require 'version'
require 'zip/zipfilesystem'

require 'rubylet/webapp_descriptor_builder'
require 'rubylet/glassfish_descriptor_builder'
require 'rubylet/jetty_descriptor_builder'

module ParamAccessor
  # Define a 'param', like attr_accessor, but with an optional default
  # value.  If params are defined as objects that respond to +:call+
  # (e.g. a +Proc+) or a block is given, the proc or block will be
  # instance_eval'ed in the context of the instance once on first
  # read, after which the value is cached and returned on subsequent
  # reads.
  def param_accessor(sym, default = nil, &block)
    if !default.nil? && block_given?
      raise ArgumentError, 'both default value and block may not be given'
    end

    iv = "@#{sym}"
    define_method(sym) do
      v = instance_variable_get(iv)
      val = if !v.nil?
              v
            elsif !default.nil?
              default
            elsif block_given?
              block
            else
              nil
            end

      if val.respond_to?(:call)
        newval = instance_eval(&val)
        instance_variable_set(iv, newval)
        newval
      else
        val
      end
    end

    define_method("#{sym}=") do |val|
      instance_variable_set(iv, val)
    end
  end
end

module CommonParams
  extend ParamAccessor
    
  param_accessor :jruby_home do
    unless self.respond_to?(:webapp) && webapp.jruby_home
      # default to the current JRuby
      if defined? JRUBY_VERSION
        regex = %r{/lib/ruby/site_ruby.*}
        $:.find { |p| p =~ regex }.gsub(regex, '')
      else
        raise "Please set jruby_home for rake task #{self}"
      end
    end
  end

  param_accessor :env do
    {}
  end

  param_accessor :gems do
    []
  end

  def gem(name, req = '>= 0')
    gems << [name, req]
  end

  # If +bundle exec+ equivalent should be used when running the
  # webapp.  Defaults to true if +Gemfile+ exists, otherwise false.
  param_accessor :bundle_exec, File.exists?('Gemfile')

  param_accessor :boot

  param_accessor :app_root, Dir.pwd

  param_accessor :servlet_class

  # Directory from which to serve static files.  Defaults to
  # "#{app_root}/public".
  param_accessor :resource_base do
    ::File.join(app_root, 'public')
  end

  param_accessor :compile_mode

  param_accessor :compat_version
    
  # CONCURRENT and SINGLETON are classloader shared singletons!
  # Probably not what you want when deploying multiple apps to one
  # servlet container.  So it's between THREADSAFE and SINGLETHREAD.
  # Default: unspecified; uses rubylet default of THREADSAFE.
  param_accessor :local_context_scope

  def common_params
    yield 'rubylet.jrubyHome', jruby_home
    env.each do |key, value|
      yield "rubylet.env.#{key}", value
    end
    gems.each do |(name, req)|
      yield "rubylet.gem.#{name}", req
    end
    yield 'rubylet.bundleExec', bundle_exec
    yield 'rubylet.boot', boot
    yield 'rubylet.servletClass', servlet_class
    yield 'rubylet.appRoot', app_root
    yield 'rubylet.compileMode', compile_mode
    yield 'rubylet.compatVersion', compat_version
    yield 'rubylet.localContextScope', local_context_scope
  end
end

class StaticFileFilter
  extend ParamAccessor

  param_accessor :name, 'StaticFileFilter'

  param_accessor :java_class, 'com.commongroundpublishing.rubylet.StaticFileFilter'

  param_accessor :doc_base

  param_accessor :async_supported, false

  param_accessor :url_pattern, '/*'

  # @param [WebappDescriptorBuilder] w
  def call(w)
    w.filter { |f|
      f.filter_name name
      f.filter_class java_class
      f.init_param! 'docBase', doc_base
      f.async_supported async_supported if async_supported
    }
    w.filter_mapping { |f|
      f.filter_name name
      f.url_pattern url_pattern
    }
  end
end

class RubyletDescriptor
  extend ParamAccessor
  include CommonParams

  # erase the defaults on these; they will be inherited from the
  # context params if not set explicitly
  param_accessor :bundle_exec
  param_accessor :app_root

  param_accessor :name do
    "Rubylet - #{File.basename(app_root)}"
  end

  param_accessor :java_servlet_class, 'com.commongroundpublishing.rubylet.RestartableServlet'

  param_accessor :url_pattern, '/*'

  param_accessor :servlet_path do
    # if url_pattern is (alpha-numeric or slashes)/*
    if url_pattern =~ /^([\w\/]+)\/\*$/
      $1
    end
  end
    
  param_accessor :async_supported, false

  attr_reader :webapp

  def initialize(webapp)
    @webapp = webapp
  end

  # @param [WebappDescriptorBuilder] w
  def call(w)
    w.servlet { |s|
      s.servlet_name name
      s.servlet_class java_servlet_class
      common_params do |key, value|
        s.init_param! key, value
      end
      s.init_param! 'servletPath', servlet_path
      s.load_on_startup 1
      s.async_supported async_supported if async_supported
    }

    w.servlet_mapping { |s|
      s.servlet_name name
      s.url_pattern url_pattern
    }
  end
end

module Rubylet
  class WarTask < Rake::TaskLib
    is_versioned

    extend ParamAccessor
    include CommonParams

    # The name of the web application.  The WAR file output will be
    # derived from this, +"#{name}.war"+.
    param_accessor :name, 'webapp'

    # The directory in which to create the WAR file.  Defaults to +./pkg+.
    param_accessor :output_directory, ::File.join(Dir.pwd, 'pkg')

    param_accessor :java_servlets_version, '3.0'

    param_accessor :display_name do
      "#{name}"
    end

    param_accessor(:listeners) { [] }

    param_accessor(:filters) { [] }

    param_accessor(:servlets) { [] }

    # TODO: currently does not work with Jetty
    param_accessor(:resources) { [] }

    def initialize
      yield(self) if block_given?
      define
    end

    def filter(&block)
      filters << block
    end

    def servlet_context_logger
      listeners << proc do |w|
        w.listener! 'com.commongroundpublishing.slf4j.impl.ServletContextListenerSCL'
      end
    end

    def external_jruby
      listeners << proc do |w|
        w.listener! 'com.commongroundpublishing.slf4j.impl.ServletContextLoggerSCL'
        w.listener! 'com.commongroundpublishing.rubylet.ExternalJRubyLoader'
      end
    end

    def static_file_filter
      f = StaticFileFilter.new
      yield(f) if block_given?
      filters << f
    end

    def servlet(&block)
      servlets << block
    end

    def rubylet
      s = RubyletDescriptor.new(self)
      yield(s) if block_given?
      servlets << s
    end

    def webapp_descriptor(opts = {})
      builder = WebappDescriptorBuilder.new(opts)
      builder.web_app!(java_servlets_version) { |w|
        w.display_name display_name()

        # If defined as context params, will apply to all Rubylet servlets
        common_params do |key, value|
          w.context_param! key, value
        end

        listeners.each do |block|
          block.call(w)
        end

        filters.each do |block|
          block.call(w)
        end

        servlets.each do |block|
          block.call(w)
        end

        resources.each do |res|
          w.resource_ref do |r|
            r.description(res[:description]) if res[:description]
            r.res_ref_name(res[:name])
            r.res_type(res[:type] || 'javax.sql.DataSource')
            r.res_auth(res[:auth] || 'Container')
          end
        end
      }
    end

    def glassfish_descriptor(opts = {})
      builder = GlassfishDescriptorBuilder.new(opts)
      builder.glassfish_web_app { |w|
        w.alternate_doc_root!('/*', resource_base)
        resources.each do |res|
          w.resource_ref do |r|
            r.res_ref_name res[:name]
            r.jndi_name res[:jndi_name] || res[:name]
          end
        end
      }
    end

    def jetty_descriptor(opts = {})
      builder = JettyDescriptorBuilder.new(opts)
      builder.configure! { |c|
        c.set!('resourceBase', resource_base)
      }
    end

    def rubylet_jar
      base = ::File.expand_path('../..', __FILE__)
      jar = Dir[::File.join(base, 'rubylet-ee-*.jar')].first
      unless jar
        raise 'cannot find rubylet-ee-VERSION.jar; was this gem built correctly?'
      end
      jar
    end

    def war(warfile)
      Zip::ZipFile.open(warfile, Zip::ZipFile::CREATE) do |z|
        z.dir.mkdir('WEB-INF')
        z.file.open('WEB-INF/web.xml', 'w') do |f|
          webapp_descriptor(:target => f)
        end
        z.file.open('WEB-INF/jetty-web.xml', 'w') do |f|
          jetty_descriptor(:target => f)
        end
        z.file.open('WEB-INF/glassfish-web.xml', 'w') do |f|
          glassfish_descriptor(:target => f)
        end

        begin
          # we are using ruby version number with "a" suffix as
          # equivalent to java/maven "-SNAPSHOT"
          ee_version = if VERSION.to_s =~ /(.*)a$/
                         "#{$1}-SNAPSHOT"
                       else
                         VERSION.to_s
                       end

          deps = MiniAether::Spec.new do
            group 'com.commongroundpublishing' do
              jar "rubylet-ee:#{ee_version}"
              jar 'slf4j-servletcontext:1.0.0'
            end
          end.resolve

          dir = 'WEB-INF/lib'
          z.dir.mkdir(dir)
          deps.each do |source|
            dest = "#{dir}/#{::File.basename(source)}"
            z.file.open(dest, 'w') do |output|
              ::File.open(source) { |input| copy_stream(input, output) }
            end
          end
        rescue => e
          raise "Error resolving dependencies: #{e}"
        end
      end
    end

    # Bug in JRuby prevents IO.copy_stream
    #
    # See https://github.com/jruby/jruby/issues/437
    def copy_stream(input, output)
      buf = ''
      while input.read(4096, buf)
        output.write(buf)
      end
    end

    # Runs maven if we are a JRuby process.  Currently not used.
    #
    # See http://watchitlater.com/blog/2011/08/jruby-rake-and-maven/
    def mvn(*args)
      mvn = catch(:mvn) do
        ENV['PATH'].split(::File::PATH_SEPARATOR).each do |path|
          Dir.glob(::File.join(path, 'mvn')).each do |file|
            if ::File.executable?(file)
              throw :mvn, if ::File.symlink?(file)
                            ::File.readlink(file)
                          else
                            file
                          end
            end
          end
        end
      end

      raise 'No maven found on $PATH' unless mvn
      
      mvn_home = ::File.expand_path(::File.join(mvn, '..', '..'))
      m2_conf = ::File.expand_path(::File.join(mvn_home, 'bin', 'm2.conf'))

      java.lang.System.setProperty('maven.home', mvn_home)
      java.lang.System.setProperty('classworlds.conf', m2_conf)

      Dir[::File.join(mvn_home, 'boot', '*.jar')].each do |jar|
        require jar
      end
      launcher = Java::org.codehaus.plexus.classworlds.launcher.Launcher
      exit_code = launcher.mainWithExitCode(args.flatten.to_java(:string))
      raise "Maven exited #{exit_code}" unless exit_code == 0
    end

    private

    def define
      rakefile = 'Rakefile'
      file rakefile

      warfile = "#{output_directory}/#{name}.war"

      file warfile => Dir['**/*rb'] do
        ::File.delete(warfile) if ::File.exists?(warfile)
        FileUtils.mkdir_p("#{output_directory}")
        war(warfile)
      end

      desc 'Create a very-skinny WAR referencing an external Rack app'
      task :war => [warfile, rakefile]

      task :clean do
        ::File.delete warfile
      end
    end

  end
end
