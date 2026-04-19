module GPX
  Line = Data.define(:start_point, :end_point) do
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
end
