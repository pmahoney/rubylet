Gem::Specification.new do |s|
  s.name        = 'rubylet-rack'
  s.version     = File.read('VERSION')
  s.platform    = 'java'
  s.authors     = ['Patrick Mahoney']
  s.email       = ['pat@polycrystal.org']
  s.description = 'Java Servlet implementation that forwards to Rack application'
  s.summary     = 'Java Servlet implementation that forwards to Rack application'
  s.files       = Dir['VERSION',
                      'MIT-LICENSE',
                      'lib/rubylet/rack/ext.jar',
                      'lib/**/*.rb',
                      'spec/**/*.rb']

  s.add_dependency 'rack'

  s.add_development_dependency 'mechanize'
  s.add_development_dependency 'mini_aether'
  s.add_development_dependency 'minitest-matchers'
  s.add_development_dependency 'rake'
  s.add_development_dependency 'version', '~> 1'
end
