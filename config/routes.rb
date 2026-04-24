Rails.application.routes.draw do
  mount MissionControl::Jobs::Engine, at: "/jobs"

  resource :session, only: [ :new, :create, :destroy ]
  resource :registration, only: [ :new, :create ]

  resources :tours do
    collection do
      get :preview_activities
    end
    member do
      patch :remove_activity
      patch :add_activities
    end
  end
  resources :activities do
    member do
      get  :truncate
      get  :split
      get  :export_gpx
      get  :export_original
      get  :export_geojson
      post :correct_elevation
      post :revert_elevation
      post   :add_to_tour
      delete :remove_from_tour
    end
  end

  # , constraints: {year: /\d{4}/, month: /0?[1-9]|1[0-2]/}
  resource :calendar, only: [] do
    get ":year",        to: "calendar/years#show",  as: :year
    get ":year/:month", to: "calendar/months#show", as: :month
  end

  resource :heatmap, only: [ :show ] do
    get ":z/:x/:y.:format", to: "tiles#show"
  end

  resource :records, only: [ :show ]
  resource :account, only: [ :show, :update ]
  resource :upload, only: [ :show ]

  get "/athlete/:id", to: "public_profiles#show", as: :public_profile
  get "/s/:token(.:format)", to: "shares#show",  as: :shared_activity
  get "/s/:token/embed",     to: "shares#embed", as: :embed_activity

  get "up" => "rails/health#show", as: :rails_health_check

  root "activities#index"
end
