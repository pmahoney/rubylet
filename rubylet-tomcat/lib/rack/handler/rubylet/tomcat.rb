require 'rack/handler'
require 'rubylet/tomcat'

Rack::Handler.register('rubylet/tomcat', Rubylet::Tomcat)
