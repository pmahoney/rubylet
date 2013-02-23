Gem::Specification.new do |s|
  s.name        = 'rubylet-tomcat'
  s.version     = File.read(File.expand_path('../VERSION', __FILE__))
  s.platform    = 'java'
  s.has_rdoc    = true
  s.summary     = 'Rack::Handler using Rubylet and Tomcat'
  s.description = ''
  s.authors     = ['Patrick Mahoney']
  s.email       = ['pat@polycrystal.org']
  s.files       = Dir['VERSION',
                      'MIT-LICENSE',
                      'lib/**/*.rb']

  s.add_dependency 'mini_aether', '>= 0.0.7'

  s.add_development_dependency 'rack'
  s.add_development_dependency 'rake'
  s.add_development_dependency 'version'
end

