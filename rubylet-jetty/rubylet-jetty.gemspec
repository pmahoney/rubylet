Gem::Specification.new do |s|
  s.name        = 'rubylet-jetty'
  s.version     = File.read(File.expand_path('../VERSION', __FILE__))
  s.platform    = 'java'
  s.has_rdoc    = true
  s.summary     = 'Rack::Handler using Rubylet and Jetty'
  s.description = ''
  s.authors     = ['CG Labs']
  s.email       = ['eng@commongroundpublishing.com']
  s.files       = Dir['VERSION',
                      'MIT-LICENSE',
                      'lib/**/*.rb',
                      'spec/**/*.rb']

  s.add_dependency 'mini_aether'

  s.add_development_dependency 'minitest'
  s.add_development_dependency 'minitest-matchers'
  s.add_development_dependency 'rack'
  s.add_development_dependency 'version'
end

