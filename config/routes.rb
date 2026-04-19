Rails.application.routes.draw do
  resource :session, only: [ :new, :destroy ]
  post "magic_links", to: "magic_links#create", as: :magic_links
  get  "magic_links/verify", to: "magic_links#verify", as: :verify_magic_link

  resources :tours
  resources :activities do
    member do
      get :truncate
      get :split
      get :export_gpx
      get :export_original
      get :export_geojson
      #      get :swap_elevation_stream # (device_elevation, calculated_elevation)
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

  resource :account, only: [ :show, :update ]
  resource :upload, only: [ :show, :create ]

  get "/athlete/:id", to: "public_profiles#show", as: :public_profile
  get "/s/:token",       to: "shares#show",  as: :shared_activity
  get "/s/:token/embed", to: "shares#embed", as: :embed_activity

  get "up" => "rails/health#show", as: :rails_health_check

  root "activities#index"
end
