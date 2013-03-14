require 'rubylet/rack/session/container_store'
TestApp::Application.config.session_store Rubylet::Rack::Session::ContainerStore
