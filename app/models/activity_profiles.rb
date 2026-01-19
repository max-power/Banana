PROFILES = {
  walking:  ActivityProfile.new(name: "Walking",  moving_speed_m_s: 0.3, max_speed_m_s: 3.0),
  running:  ActivityProfile.new(name: "Running",  moving_speed_m_s: 0.7, max_speed_m_s: 8.0),
  cycling:  ActivityProfile.new(name: "Cycling",  moving_speed_m_s: 1.5, max_speed_m_s: 20.0),
  driving:  ActivityProfile.new(name: "Driving",  moving_speed_m_s: 5.0, max_speed_m_s: 60.0),
  default:  ActivityProfile.new(name: "Default",  moving_speed_m_s: 0.5, max_speed_m_s: 60.0)
}.freeze
