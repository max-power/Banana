Rails.application.routes.draw do
    resources :activities do
        member do
            get :truncate
            get :split
            get :export_gpx
            get :export_original
            #      get :swap_elevation_stream # (device_elevation, calculated_elevation)
        end
    end

    # , constraints: {year: /\d{4}/, month: /0?[1-9]|1[0-2]/}
    resource :calendar, only: [] do
        get ":year",        to: "calendar/years#show",  as: :year
        get ":year/:month", to: "calendar/months#show", as: :month
    end

    resource :heatmap, only: [:show] do
        get ':z/:x/:y.:format', to: 'tiles#show'
    end

    resource :account, only: [:show]
    resource :upload, only: [:show, :create]

    get "up" => "rails/health#show", as: :rails_health_check

    root "pages#index"
end
