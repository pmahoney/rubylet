TestApp::Application.routes.draw do
  get 'tests/log', :to => 'tests#log'
  get 'tests/large/:size', :to => 'tests#large'
  resources :session_values
  root :to => 'tests#index'
end
