Gem::Specification.new do |s|
  s.name        = 'rubylet'
  s.version     = File.read('VERSION')
  s.platform    = 'java'
  s.authors     = ["CG Labs"]
  s.email       = ['eng@commongroundpublishing.com']
  s.description = 'Java Servlet implementation that forwards to Rack application'
  s.summary     = 'Java Servlet implementation that forwards to Rack application'
  s.files        = Dir['lib/**/*.rb', 'spec/**/*.rb']

  s.add_development_dependency 'minitest-matchers'
  s.add_development_dependency 'rake'
  s.add_development_dependency 'version', '~> 1'
end
