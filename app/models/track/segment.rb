module Track
  Segment = Data.define(:points, :index) do
    def start_point = points.first
    def end_point   = points.last

    def start_time  = start_point.time
    def end_time    = end_point.time

    def coordinates
      points.map(&:to_coordinates)
    end

    def distance_m
      points.each_cons(2).sum { |p1, p2| p1.distance_to(p2) }
    end

    def moving_time_s(profile: nil, pause_gap_s: 300)
      points.each_cons(2).sum do |p1, p2|
        Line.new(p1, p2).moving_duration(pause_gap_s, profile: profile)
      end
    end
  end
end
