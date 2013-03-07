class RubyletHelper
  name = 'com.commonground.rubylet.jruby.' + self.to_s
  @logger = Java::OrgSlf4j::LoggerFactory.getLogger(name)
  
  class << self
    def logger
      @logger
    end    
  end
  
  def logger
    self.class.logger
  end
  
  # @param [com.commongroundpublishing.rubylet.jruby.RubyConfig] config
  def boot(config)
    config.env.each do |key,value|
      logger.debug "ENV[{}] = {}", key, value
      ENV[key] = value
    end
      
    if File.exists?('lib')
      logger.debug("adding 'lib' to $LOAD_PATH")
      $LOAD_PATH << 'lib'
    end
      
    # Can be used to circumvent bundler by adding gems to the
    # $LOAD_PATH before bundler is setup.  This may result in
    # conflicts and is intended to be used to load 'rubylet/servlet'
    # without needing to add it to the Gemfile.
    orig_load_path = $LOAD_PATH.dup
    config.gems.each do |name, req|
      require 'rubygems'
      logger.debug "gem {}, {}", name, req
      gem name, req
    end
    # These paths are saved separately because bundle_exec removes them
    gems_paths = $LOAD_PATH - orig_load_path
      
    if config.bundle_exec?
      ENV['BUNDLE_GEMFILE'] ||= File.join(Dir.pwd, config.bundle_gemfile)
      ENV['BUNDLE_WITHOUT'] ||= config.bundle_without

      logger.info("bundler with gemfile={} without={}",
                  config.bundle_gemfile,
                  config.bundle_without)
      require 'rubygems'
      require 'bundler/setup'

      # Restore any gems we want available in spite of bundle exec
      gems_paths.each { |p| $LOAD_PATH.push p }
    end

    # require config.boot
    if config.boot
      logger.debug "boot with {}", config.boot
      load File.join(Dir.pwd, config.boot)
    end
    
    if config.servlet_class == 'Rubylet::Servlet'
      logger.debug "require 'rubylet'"
      require 'rubylet'
    end 
  end
    
  # Create a new object instance based on a string
  # class name like 'SomeModule::SomeClass'.  Will
  # fail with absolute class like '::SomeClass'
  def new_instance(klass)
    logger.debug "new {} instance", klass
    to_class(klass).new
  end
    
  # Convert string like 'Some::Class::Name' into the corresponding
  # constant.  Will fail with '::Some::Class'.
  def to_class(str)
    str.split('::').inject(Kernel) { |scope, s|
      scope.const_get(s)
    }
  end
end
