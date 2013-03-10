require 'rubylet/dechunking_body'
require 'rubylet/errors'
require 'rubylet/ext'
require 'rubylet/rewindable_io'
require 'rubylet/session/container_store'

module Rubylet
  # some constants used by various modules
  CONTENT_LENGTH    = 'Content-Length'.freeze
  CONTENT_TYPE      = 'Content-Type'.freeze
  TRANSFER_ENCODING = 'Transfer-Encoding'.freeze

  # optional cgi keys
  REMOTE_USER = 'REMOTE_USER'.freeze
        
  EMPTY_STRING = ''.freeze
        
  GET     = 'GET'.freeze
  PUT     = 'PUT'.freeze
  POST    = 'POST'.freeze
  DELETE  = 'DELETE'.freeze
  OPTIONS = 'OPTIONS'.freeze
  HEAD    = 'HEAD'.freeze

  # common http headers
  HTTP_ACCEPT     = 'HTTP_ACCEPT'.freeze
  HTTP_CONNECTION = 'HTTP_CONNECTION'.freeze
  HTTP_HOST       = 'HTTP_HOST'.freeze
  HTTP_USER_AGENT = 'HTTP_USER_AGENT'.freeze

  ASYNC_THROWN = Object.new.freeze

  # Extension for Servlet since I don't know how to catch/throw on the
  # Java side.
  class Servlet
    def call(app, env)
      catch(:async) do
        return app.call(env)
      end
      return ASYNC_THROWN
    end
  end
end
