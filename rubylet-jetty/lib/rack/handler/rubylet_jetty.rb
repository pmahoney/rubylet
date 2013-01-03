require 'rack/handler'
require 'rubylet/jetty'

# rack 1.2's handler loading is a bit different.  Commandline: rackup -s RubyletJetty
Rack::Handler::RubyletJetty = Rubylet::Jetty

