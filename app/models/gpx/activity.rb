module GPX
  class Activity
    attr_reader :parser, :segments

    def initialize(gpx_data, profile: nil)
      @parser = Parser.new(gpx_data, profile: profile)
      @segments = @parser.segments
    end

    def metadata
      {
        activity_type:    parser.activity_type,
        activity_name:    parser.activity_name,
        distance_m:       total_distance&.round(2),
        time_start:       time_start,
        time_end:         time_end,
        time_elapsed_s:   elapsed_time_s&.round,
        time_moving_s:    moving_time_s&.round,
        time_paused_s:    paused_time_s&.round,

        average_speed_m_s: total_distance && moving_time_s&.positive? ? (total_distance / moving_time_s).round(3) : nil,
        max_speed_m_s:    max_speed_m_s&.round(3),

        elevation_gain_m: elevation.gain,
        elevation_loss_m: elevation.loss,
        elevation_net_m:  elevation.net,
        elevation_min_m:  elevation.min,
        elevation_max_m:  elevation.max,

        #coordinates:      flattened_coordinates,
        segments: segments_metadata,

        cleanup: parser.clean_report.to_h
      }
    end

    def to_h
      metadata
    end

    private

    def total_distance
      @total_distance ||= segments.sum(&:distance_m)
    end

    def moving_time_s
      @moving_time_s ||= segments.sum { |s| s.moving_time_s(profile: parser.profile) }
    end

    def paused_time_s
      @paused_time_s ||= segments.sum do |s|
        s.points.each_cons(2).sum do |p1, p2|
          seg = Line.new(p1, p2)
          seg.paused_duration(Cleaner::PAUSE_GAP_S)
        end
      end
    end

    def elapsed_time_s
      return 0 unless time_start && time_end
      time_end - time_start
    end

    def time_start
      segments.first&.start_time
    end

    def time_end
      segments.last&.end_time
    end

    def max_speed_m_s
      segments.flat_map(&:points).each_cons(2).filter_map do |p1, p2|
        line = Line.new(p1, p2)
        line.speed if line.moving?(profile: parser.profile)
      end.max
    end

    def elevation
      @elevation ||= ElevationMetric.new(segments.flat_map(&:points))
    end

    def segments_metadata
      segments.map do |seg|
        {
          index: seg.index,
          start_time: seg.start_time,
          end_time: seg.end_time,
          distance_m: seg.distance_m&.round(2),
          moving_time_s: seg.moving_time_s(profile: parser.profile)&.round,
          coordinates: seg.coordinates
        }
      end
    end
  end
end
