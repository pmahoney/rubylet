require 'rubylet/rack/errors'

# TODO: should this wrap slf4j or something?  Or is it typically overridden
# by the rack application?
module Rubylet
  module Rack
    class Logger < Rubylet::Errors
      
      def info(message = nil, &block)
        log(:info, message, &block)
      end
      
      def debug(message = nil, &block)
        log(:debug, message, &block)
      end
      
      def warn(message = nil, &block)
        log(:warn, message, &block)
      end
      
      def error(message = nil, &block)
        log(:error, message, &block)
      end
      
      def fatal(message = nil, &block)
        log(:fatal, message, &block)
      end
      
      def log(level, message = nil, &block)
        msg = if message
                message
              elsif block_given?
                yield
              end
        
        write("#{level.to_s.upcase}: #{msg}")
      end
    end
  end
end
