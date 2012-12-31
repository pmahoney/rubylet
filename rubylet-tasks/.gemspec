Gem::Specification.new do |s|
  s.name        = 'rubylet-tasks'
  s.version     = File.read(File.expand_path('../VERSION', __FILE__))
  s.platform    = 'java'
  s.has_rdoc    = true
  s.summary     = 'Rake tasks for rubylet, rubylet-ee, and Java servlets'
  s.description = ''
  s.authors     = ['CG Labs']
  s.email       = ['eng@commongroundpublishing.com']
  s.files       = Dir['VERSION',
                      'MIT-LICENSE',
                      'lib/**/*.rb',
                      'lib/**/*.jar',
                      'spec/**/*.rb',
                      'examples/**/*']

  s.add_dependency 'builder'
  s.add_dependency 'mini_aether'
  s.add_dependency 'rake'
  s.add_dependency 'zip'

  s.add_development_dependency 'minitest'
  s.add_development_dependency 'minitest-matchers'
  s.add_development_dependency 'version'
end

