module Rubylet
  # Class-level lifecycle events.
  module ClassLifecycle
    def run(*args, &block)
      before_class
      super
    ensure
      after_class
    end

    def before_class; end

    def after_class; end
  end
end
