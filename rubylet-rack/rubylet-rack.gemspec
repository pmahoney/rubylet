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
  s.add_development_dependency 'minitest', '~> 5.0.6'
  s.add_development_dependency 'minitest-matchers', '~> 1.4.0'
  s.add_development_dependency 'rake'
  # mechanize -> domain_name -> unf, but unf_ext 0.0.6 breaks on JRuby
  s.add_development_dependency 'unf', '<= 0.0.5'
  s.add_development_dependency 'version', '~> 1'
end
