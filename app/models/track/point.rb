module Track
  Point = Data.define(:lat, :lon, :elevation, :time) do
    ZERO_EPSILON = 1e-6

    def zero?
      lat.abs < ZERO_EPSILON && lon.abs < ZERO_EPSILON
    end

    def distance_to(other)
      Haversine.distance(lat, lon, other.lat, other.lon).to_meters
    end

    def time_difference_to(other)
      (time - other.time).abs if time && other.time
    end

    def to_coordinates
      [lat, lon, elevation]
    end
  end
end
