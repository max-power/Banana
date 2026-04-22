module ActivityType
  GROUPED = {
    "Cycling"       => %w[cycling mountain_bike_ride gravel_ride e_bike_ride e_mountain_bike_ride velomobile virtual_ride handcycle],
    "On foot"       => %w[running hiking walking trail_run virtual_run inline_skate roller_ski],
    "Watersports"   => %w[swim canoeing kayaking kitesurf rowing sail stand_up_paddling surfing windsurf],
    "Winter sports" => %w[alpine_ski backcountry_ski nordic_ski snowboard ice_skate snowshoe],
    "Gym & fitness" => %w[yoga pilates crossfit weight_training high_intensity_interval_training stair_stepper workout],
    "Racket sports" => %w[tennis squash badminton padel pickleball racquetball table_tennis],
    "Team sports"   => %w[soccer basketball volleyball cricket],
    "Other"         => %w[rock_climbing skateboard golf dance virtual_row wheelchair],
  }.freeze

  ALL = GROUPED.values.flatten.freeze

  def self.all      = ALL
  def self.grouped  = GROUPED
  def self.for_select
    GROUPED.map { |group, types| [group, types.map { |t| [t.humanize, t] }] }
  end
end
