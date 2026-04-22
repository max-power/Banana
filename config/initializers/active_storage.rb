require_relative Rails.application.root.join('app', 'analyzers', 'gpx_analyzer.rb')
require_relative Rails.application.root.join('app', 'models', 'activity_profile.rb')
require_relative Rails.application.root.join('app', 'models', 'fit.rb')
require_relative Rails.application.root.join('app', 'models', 'fit', 'parser.rb')
require_relative Rails.application.root.join('app', 'models', 'fit', 'activity.rb')
require_relative Rails.application.root.join('app', 'analyzers', 'fit_analyzer.rb')

Rails.application.config.active_storage.analyzers.append GpxAnalyzer
Rails.application.config.active_storage.analyzers.append FitAnalyzer
