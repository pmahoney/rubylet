require 'rubylet/session'

# Rack middleware to make the servlet container's sessions available to ruby.
module Rubylet
  class Session
    class ContainerStore
      def initialize(app, options={})
        @app = app
        @options = options
      end

      def call(env)
        context(env)
      end

      # For Rack::Util::Context
      def context(env, app=@app)
        if req = env['java.servlet_request']
          env['rack.session'] = Session.new(req, @options)
        else
          env['rack.errors'].puts 'java.servlet_request not found; cannot make session'
        end
        app.call(env)
      end
    end
  end
end
