class WelcomeController < ApplicationController
  def index
    @hello = 'Hello'
    @world = 'world!'
  end
end
