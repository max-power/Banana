namespace :heatmap do
  desc <<~DESC
    Recompute activity_tiles. Optional args: user_email, from_zoom, to_zoom.
      bin/rails heatmap:rebuild
      bin/rails "heatmap:rebuild[you@example.com]"
      bin/rails "heatmap:rebuild[,15]"
      bin/rails "heatmap:rebuild[,15,16]"
      bin/rails "heatmap:rebuild[you@example.com,15,16]"
  DESC
  task :rebuild, [ :user_email, :from_zoom, :to_zoom ] => :environment do |_, args|
    users    = args[:user_email].present? ? User.where(email: args[:user_email]) : User.all
    min_zoom = args[:from_zoom].present? ? args[:from_zoom].to_i : 0
    max_zoom = args[:to_zoom].present?   ? args[:to_zoom].to_i   : ComputeActivityTilesJob::MAX_ZOOM

    zoom_label = " (zoom #{min_zoom}–#{max_zoom})"

    users.each do |user|
      activities = Activity.where(user: user, type: nil).order(:start_time)
      total      = activities.count
      puts "Rebuilding tiles#{zoom_label} for #{user.email} — #{total} activities"

      activities.each_with_index do |activity, i|
        label = [
          activity.start_time&.strftime("%Y-%m-%d"),
          activity.activity_type,
          activity.name&.truncate(40),
        ].compact.join("  ")

        print "  [%#{total.to_s.length}d/#{total}] #{label} ... " % (i + 1)
        $stdout.flush

        started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        begin
          ComputeActivityTilesJob.perform_now(activity.id, min_zoom: min_zoom, max_zoom: max_zoom)
          elapsed = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1000).round
          puts "done (#{elapsed}ms)"
        rescue => e
          puts "FAILED"
          puts "         #{e.class}: #{e.message}"
          e.backtrace.first(3).each { |line| puts "         #{line}" }
        end
      end

      puts "Finished #{user.email}."
    end
  end

  desc "Clear all activity_tiles. Pass user_email to limit to one user."
  task :clear, [ :user_email ] => :environment do |_, args|
    scope = args[:user_email] ? ActivityTile.where(user_id: User.find_by!(email: args[:user_email]).id) : ActivityTile.all
    count = scope.delete_all
    puts "Deleted #{count} tile rows."
  end
end
