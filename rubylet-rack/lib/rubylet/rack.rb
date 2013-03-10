require 'rubylet/rack/dechunking_body'
require 'rubylet/rack/errors'
require 'rubylet/rack/ext'
require 'rubylet/rack/rewindable_io'
require 'rubylet/rack/session/container_store'

# Extension for Servlet since I don't know how to catch/throw on the
# Java side.
class Rubylet::Rack::Servlet
  ASYNC_THROWN = Object.new.freeze

  def call(app, env)
    catch(:async) do
      return app.call(env)
    end
    return ASYNC_THROWN
  end
end
