ActivityProfile = Data.define(:name, :moving_speed_m_s, :max_speed_m_s) do
  PROFILES = {
    cycling: new(name: "Cycling", moving_speed_m_s: 1.5, max_speed_m_s: 27.0), # ~97 km/h — allows fast descents
    running: new(name: "Running", moving_speed_m_s: 0.7, max_speed_m_s:  9.0), # ~32 km/h
    walking: new(name: "Walking", moving_speed_m_s: 0.3, max_speed_m_s:  4.0), # ~14 km/h
  }.freeze

  ALIASES = {
    mountain_bike_ride:   :cycling,
    gravel_ride:          :cycling,
    e_bike_ride:          :cycling,
    e_mountain_bike_ride: :cycling,
    velomobile:           :cycling,
    virtual_ride:         :cycling,
    handcycle:            :cycling,
    trail_run:            :running,
    virtual_run:          :running,
    hiking:               :walking,
    inline_skate:         :walking,
    roller_ski:           :walking,
  }.freeze

  DEFAULT = new(name: "Default", moving_speed_m_s: 0.5, max_speed_m_s: 60.0)

  def self.for(activity_type)
    key = ALIASES[activity_type.to_sym] || activity_type.to_sym
    PROFILES[key] || DEFAULT
  end

  def valid_speed?(speed)
    speed >= moving_speed_m_s && speed <= max_speed_m_s
  end
end
