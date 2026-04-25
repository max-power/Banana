module Track
  class Cleaner
    MAX_JUMP_M  = 500.0
    PAUSE_GAP_S = 300 # 5 min

    class Counter
      def initialize    = @counts = Hash.new(0)
      def inc(key, n=1) = @counts[key] += n
      def get(key)      = @counts[key]
      def to_h          = @counts
    end

    attr_reader :profile, :counter

    def initialize(profile = nil)
      @profile = profile
      @counter = Counter.new
    end

    def segments(points)
      return [] if points.empty?
      build_segments(points)
    end

    private

    def build_segments(points)
      segments = []
      current  = []

      points.each do |point|
        if should_split?(current.last, point)
          push_segment!(segments, current)
          current = []
        end

        current << point
      end

      push_segment!(segments, current)
      segments
    end

    def should_split?(prev, current)
      return false unless current
      return true if prev.nil? || reject_zero_point?(current)

      line = Line.new(prev, current)

      if line.duration
        return true if reject_time_error?(line.duration)
        return true if reject_speed_jump?(line.speed)
        return true if reject_paused?(line)
      end

      return true if reject_distance_jump?(line.distance)

      false
    end

    def push_segment!(segments, current)
      return if current.size < 2
      segments << Segment.new(current.dup, segments.size)
    end

    def reject_zero_point?(point)
      point.zero? && report(:zero_points)
    end

    def reject_time_error?(diff)
      diff <= 0 && report(:time_errors)
    end

    def reject_speed_jump?(speed)
      # Only reject impossibly fast speeds (GPS teleportation errors).
      # Slow movement is always legitimate — min-speed filtering belongs in
      # moving-time calculation, not here.
      profile && speed && speed > profile.max_speed_m_s && report(:speed_jumps)
    end

    def reject_distance_jump?(dist)
      dist > MAX_JUMP_M && report(:distance_jumps)
    end

    def reject_paused?(line)
      line.paused?(PAUSE_GAP_S) && report(:pauses)
    end

    def report(key)
      counter.inc(key)
      true
    end
  end
end
