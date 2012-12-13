require 'rack/handler'
require 'rubylet/jetty'

Rack::Handler.register('rubylet/jetty', Rubylet::Jetty)

