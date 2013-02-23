require 'rack/handler'
require 'rubylet/tomcat'

# rack 1.2's handler loading is a bit different.  Commandline: rackup -s RubyletTomcat
Rack::Handler::RubyletTomcat = Rubylet::Tomcat

