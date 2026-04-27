Rails.application.config.after_initialize do
  Rails.application.config.active_storage.analyzers.append GPXAnalyzer
  Rails.application.config.active_storage.analyzers.append FITAnalyzer
end
