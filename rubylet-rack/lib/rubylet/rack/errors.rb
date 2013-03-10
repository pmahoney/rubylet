# Implements the rack.errors interface, logging everything via
# ServletContext#log
module Rubylet
  module Rack
    class Errors
      def initialize(context)
        @context = context
      end

      def puts(obj)
        write(obj.to_s)
      end

      def write(str)
        @context.log(str)
      end

      # A no-op for ServletContext#log
      def flush; end

      # Spec says this must never be called
      def close; end
    end
  end
end
