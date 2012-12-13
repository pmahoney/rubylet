Rails3012::Application.routes.draw do
  root :to => "welcome#index"
  resources :photos
end
