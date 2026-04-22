module FIT
  class Activity
    def initialize(data)
      @parser = Parser.new(data).parse
    end

    def to_h
      points  = @parser.records
      session = @parser.session
      return {} if points.empty?

      segments   = Track::Cleaner.new.segments(points)
      all_points = segments.flat_map(&:points)
      elevation  = Track::ElevationMetric.new(all_points)

      {
        activity_name:     nil,  # FIT files rarely carry a human-readable name
        activity_type:     SPORT_TYPES[session[:sport]] || "workout",
        distance_m:        session[:distance_m] || total_distance(all_points),
        elevation_gain_m:  elevation.gain,
        elevation_loss_m:  elevation.loss,
        time_start:        all_points.first.time,
        time_end:          all_points.last.time,
        time_elapsed_s:    session[:elapsed_time_s] || elapsed_time(all_points),
        time_moving_s:     session[:moving_time_s]  || moving_time_s(segments),
        average_speed_m_s: session[:avg_speed_m_s],
        max_speed_m_s:     session[:max_speed_m_s],
        device:            @parser.device,
        segments:          segments_metadata(segments),
      }
    end

    private

    def segments_metadata(segments)
      segments.map do |seg|
        {
          index:         seg.index,
          coordinates:   seg.coordinates,
          start_time:    seg.start_time,
          end_time:      seg.end_time,
          distance_m:    seg.distance_m.round(2),
          moving_time_s: seg.moving_time_s,
        }
      end
    end

    def total_distance(points)
      points.each_cons(2).sum { |a, b| a.distance_to(b) }.round(2)
    end

    def elapsed_time(points)
      first_ts = points.first&.time
      last_ts  = points.last&.time
      return nil unless first_ts && last_ts
      (last_ts - first_ts).round
    end

    def moving_time_s(segments)
      segments.sum(&:moving_time_s).round
    end
  end
end
