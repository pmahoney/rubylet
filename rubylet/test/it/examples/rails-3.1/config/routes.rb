TestApp::Application.routes.draw do
  match 'tests/log', :to => 'tests#log'
  resources :session_values
  root :to => 'tests#index'
end
