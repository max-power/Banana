namespace :activities do
  desc "Re-run GPS file analysis for all activities (or a single one via ACTIVITY_ID=...)"
  task reprocess: :environment do
    analyzers = [ GpxAnalyzer, FitAnalyzer ]
    scope = Activity.where(type: nil).where.associated(:file_attachment)
    scope = scope.where(id: ENV["ACTIVITY_ID"]) if ENV["ACTIVITY_ID"].present?
    total = scope.count
    puts "Reprocessing #{total} activit#{total == 1 ? "y" : "ies"}..."

    ok = missing = failed = 0

    scope.find_each.with_index(1) do |activity, i|
      blob     = activity.file.blob
      analyzer = analyzers.find { |a| a.accept?(blob) }
      unless analyzer
        failed += 1
        next print "\r#{i}/#{total}  (#{ok} ok, #{missing} missing, #{failed} failed)"
      end

      begin
        fresh = analyzer.new(blob).metadata
      rescue ActiveStorage::FileNotFoundError
        missing += 1
        next print "\r#{i}/#{total}  (#{ok} ok, #{missing} missing, #{failed} failed)"
      rescue => e
        failed += 1
        puts "\n  Error on #{activity.id}: #{e.message}"
        next print "\r#{i}/#{total}  (#{ok} ok, #{missing} missing, #{failed} failed)"
      end

      activity.send(:insert_segments, fresh[:segments])
      activity.update_columns(
        distance:       fresh[:distance_m],
        elevation_gain: fresh[:elevation_gain_m],
        elevation_loss: fresh[:elevation_loss_m],
        moving_time:    fresh[:time_moving_s],
        elapsed_time:   fresh[:time_elapsed_s],
        average_speed:  fresh[:average_speed_m_s],
        max_speed:      fresh[:max_speed_m_s],
      )
      activity.send(:update_track_3857)
      blob.update!(metadata: blob.metadata.merge(fresh))
      ComputeActivityTilesJob.perform_later(activity.id)
      ok += 1
      print "\r#{i}/#{total}  (#{ok} ok, #{missing} missing, #{failed} failed)"
    end

    puts "\nDone — #{ok} reprocessed, #{missing} missing files, #{failed} failed."
  end
end

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
