# Pin npm packages by running ./bin/importmap

pin "application"
pin "@hotwired/turbo-rails", to: "turbo.min.js"
pin "@hotwired/stimulus", to: "stimulus.min.js"
pin "@hotwired/stimulus-loading", to: "stimulus-loading.js"
pin_all_from "app/javascript/controllers", under: "controllers"
pin "maplibre-gl" # @5.16.0
pin "@rails/activestorage", to: "@rails--activestorage.js" # @8.1.200
pin "maplibre-gl-style-flipper" # @1.0.9
