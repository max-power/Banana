module GPX
    Point = Data.define(:lat, :lon, :elevation, :time, :meta) do
        ZERO_EPSILON = 1e-6

        def self.from_xml(node)
            x = node[:lat].to_f
            y = node[:lon].to_f
            z = node.at_xpath("ele")&.text.to_f || 0.0
            t = Time.iso8601(node.at_xpath("time")&.text).to_f rescue nil
            m =  {}
            new(x, y, z, t, m)
        end

        def zero?
            lat < ZERO_EPSILON && lon < ZERO_EPSILON
        end

        def distance_to(other)
            Haversine.distance(lat, lon, other.lat, other.lon).to_meters
        end

        def time_difference_to(other)
            (time - other.time).abs if time && other.time
        end
    end

    Segment = Data.define(:start_point, :end_point) do
        def distance
            start_point.distance_to(end_point)
        end

        def duration
            start_point.time_difference_to(end_point)
        end

        def speed
            duration && duration > 0 ? distance / duration : nil
        end

        def pace
            speed && speed > 0 ? 1.0 / speed : nil
        end

        def elevation_gain
            [end_point.elevation - start_point.elevation, 0].max
        end

        def elevation_loss
            [start_point.elevation - end_point.elevation, 0].max
        end

        def grade
            distance > 0 ? (end_point.elevation - start_point.elevation) / distance : nil
        end

        def grade_percent
            grade * 100.0 rescue nil
        end

        def valid?
            duration && duration > 0 && speed
        end

        def valid_speed?(profile: nil)
            !profile || profile.valid_speed?(speed)
        end

        def moving?(pause_threshold_s = 300, profile: nil)
            valid? && !paused?(pause_threshold_s) && valid_speed?(profile: profile)
        end

        def paused?(pause_threshold_s = 300)
            duration && duration > pause_threshold_s
        end

        def moving_duration(pause_threshold_s = 300, profile: nil)
            moving?(pause_threshold_s, profile: profile) ? duration : 0
        end

        def paused_duration(pause_threshold_s = 300)
            paused?(pause_threshold_s) ? duration : 0
        end
    end

    class Parser
        attr_reader :profile

        def initialize(data, profile: nil)
            @data = data
            @profile = profile || default_profile
            @cleaner = Cleaner.new(profile)
        end

        def parsed_document
            @parsed_document ||= Nokogiri::XML(@data).remove_namespaces!
        end

        def activity_name
            parsed_document.at_xpath("//trk/name")&.text
        end

        def activity_type
            parsed_document.at_xpath("//trk/type")&.text
        end

        def raw_points
            @raw_points ||= parsed_document.xpath("//trkpt").map { Point.from_xml(it) }
        end

        def clean_points
            @clean_points ||= @cleaner.filter(raw_points)
        end

        def clean_report
            @cleaner.counter
        end

        def default_profile
            ActivityProfile.new(name: "Default",  moving_speed_m_s: 0.5, max_speed_m_s: 60.0)
        end
    end

    class Cleaner
        MAX_JUMP_M = 500.0

        class Counter
            def initialize    = @counts = Hash.new(0)
            def inc(key, n=1) = @counts[key] += n
            def get(key)      = @counts[key]
            def to_h          = @counts
        end

        attr_reader :profile, :points, :counter

        def initialize(profile)
            @profile = profile
            @counter = Counter.new
        end

        def filter(points)
            points.each_with_object([]) do |point, cleaned|
                next if reject_zero_point?(point)
                next if reject_jump?(point, cleaned.last)
                cleaned << point
            end
        end

        private

        def reject_jump?(point, previous)
            return false unless previous

            segment = Segment.new(previous, point)

            if segment.duration
                reject_time_error?(segment.duration) || reject_speed_jump?(segment.speed)
            else
                reject_distance_jump?(segment.distance)
            end
        end

        def reject_zero_point?(point)
            point.zero? && report(:zero_points)
        end

        def reject_time_error?(diff)
            diff <= 0 && report(:time_errors)
        end

        def reject_speed_jump?(speed)
            profile && !profile.valid_speed?(speed) && report(:speed_jumps)
        end

        def reject_distance_jump?(dist)
            dist > MAX_JUMP_M && report(:distance_jumps)
        end

        def report(key)
            counter.inc(key)
            true
        end
    end

    class ElevationMetric
        attr_reader :profile

        def initialize(points)
          @profile = points.map(&:elevation).compact
        end

        def gain    = deltas.select(&:positive?).sum.round
        def loss    = deltas.select(&:negative?).sum.abs.round
        def net     = (profile.last - profile.first).round
        def min     = profile.min&.round || 0
        def max     = profile.max&.round || 0
        def range   = (max - min)

        private

        def deltas
          @deltas ||= profile.each_cons(2).map { |e1, e2| e2 - e1 }
        end
    end

    class TimeMetric
        PAUSE_GAP_S = 300 # 5 min

        def initialize(points, activity_profile)
            @profile = activity_profile
            @points  = points
        end

        def start_time = times.min
        def end_time   = times.max

        def elapsed_time_s
            return 0 unless start_time && end_time
            end_time - start_time
        end

        def moving_time_s
            segments.sum { |seg| seg.moving_duration(PAUSE_GAP_S, profile: @profile) }
        end

        def paused_time_s
            segments.sum { |seg| seg.paused_duration(PAUSE_GAP_S) }
        end

        private

        def times
            @times ||= @points.map(&:time).compact
        end

        def segments
            @segments ||= @points.each_cons(2).map { |p1, p2| Segment.new(p1, p2) }
        end
    end


    class DistanceMetric
        def initialize(points)
            @segments = Array(points).each_cons(2).map { |p1, p2| Segment.new(p1, p2) }
        end

        def total_distance
            @segments.sum(&:distance)
        end
    end

    class Activity
        attr_reader :parser, :points

        def initialize(gpx_data, profile: nil)
            @parser = Parser.new(gpx_data, profile: profile)
            @points = @parser.clean_points
        end

        def metadata
            {
                activity_type:     parser.activity_type,
                activity_name:     parser.activity_name,
                distance_m:        distance.total_distance.round(2),
                elevation_gain_m:  elevation.gain,
                elevation_loss_m:  elevation.loss,
                elevation_net_m:   elevation.net,
                elevation_min_m:   elevation.min,
                elevation_max_m:   elevation.max,
                time_start:        time.start_time,
                time_end:          time.end_time,
                time_elapsed_s:    time.elapsed_time_s.round,
                time_moving_s:     time.moving_time_s.round,
                time_paused_s:     time.paused_time_s.round,
                coordinates:       coordinates,
                cleanup:           parser.clean_report.to_h
            }
        end

        def to_h
            metadata
        end

        private

        def elevation
            @elevation ||= ElevationMetric.new(points)
        end

        def distance
            @distance ||= DistanceMetric.new(points)
        end

        def time
            @time ||= TimeMetric.new(points, parser.profile)
        end

        def coordinates
            points.map { |p| [p.lat, p.lon, p.elevation] }
        end
    end
end
