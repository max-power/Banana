ActivityProfile = Data.define(:name, :moving_speed_m_s, :max_speed_m_s) do
  def valid_speed?(speed)
    valid_moving_speed?(speed) && valid_max_speed?(speed)
  end

  def valid_moving_speed?(speed)
    speed >= moving_speed_m_s
  end

  def valid_max_speed?(speed)
    speed <= max_speed_m_s
  end
end
