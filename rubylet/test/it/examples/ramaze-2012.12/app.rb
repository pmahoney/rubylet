require 'ramaze'

# Make sure that Ramaze knows where you are
Ramaze.options.roots = [__DIR__]

class Controller < Ramaze::Controller
  layout :default
  helper :xhtml
  engine :etanni
end

class MainController < Controller
  def index
    @title = 'Welcome to Ramaze!'
    'tests/index'
  end
end

class SessionValuesController < Controller
  def index(key)
    if request.params['value']
      session[key] = request.params['value']
    end
    "session[#{key}] = #{session[key]}"
  end
end

class TestsController < Controller
  def log
    "i didn't actually log anything"
  end
end
