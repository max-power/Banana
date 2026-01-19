require_relative Rails.application.root.join('app', 'analyzers','gpx_analyzer.rb')

Rails.application.config.active_storage.analyzers.append GpxAnalyzer
