require ::File.expand_path('../app', __FILE__)

Ramaze.middleware :dev do
  use Rack::Lint
  run Ramaze.core
end

Ramaze.start(:root => Ramaze.options.roots, :started => true)

run Ramaze
