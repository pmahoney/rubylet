TestApp::Application.routes.draw do
  match 'tests/log', :to => 'tests#log'
  match 'tests/large/:size', :to => 'tests#large'
  resources :session_values
  root :to => 'tests#index'
end
