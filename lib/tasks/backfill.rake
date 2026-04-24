namespace :backfill do
  desc "Re-parse GPS files to populate utc_offset for all activities missing it"
  task utc_offsets: :environment do
    scope = Activity.where(type: nil, utc_offset: nil).where.associated(:file_attachment)
    total = scope.count
    puts "Backfilling utc_offset for #{total} activities..."

    analyzers = [ GpxAnalyzer, FitAnalyzer ]

    scope.find_each.with_index(1) do |activity, i|
      blob = activity.file.blob
      analyzer = analyzers.find { |a| a.accept?(blob) }
      if analyzer
        meta = analyzer.new(blob).metadata rescue {}
        offset = meta[:utc_offset]
        activity.update_column(:utc_offset, offset) unless offset.nil?
      end
      print "\r#{i}/#{total}"
    end

    puts "\nDone."
  end
end
