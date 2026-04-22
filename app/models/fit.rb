module FIT
  FIT_EPOCH   = 631065600       # seconds from Unix epoch to FIT epoch (1989-12-31 00:00:00 UTC)
  SEMICIRCLES = 180.0 / (2**31) # convert FIT semicircles to degrees

  # [byte_size, little_endian_format, big_endian_format, invalid_sentinel]
  BASE_TYPES = {
    0x00 => [ 1, "C",  "C",  0xFF                 ],  # enum
    0x01 => [ 1, "c",  "c",  0x7F                 ],  # sint8
    0x02 => [ 1, "C",  "C",  0xFF                 ],  # uint8
    0x83 => [ 2, "s<", "s>", 0x7FFF               ],  # sint16
    0x84 => [ 2, "S<", "S>", 0xFFFF               ],  # uint16
    0x85 => [ 4, "l<", "l>", 0x7FFFFFFF           ],  # sint32
    0x86 => [ 4, "L<", "L>", 0xFFFFFFFF           ],  # uint32
    0x07 => [ 1, "a*", "a*", nil                  ],  # string
    0x88 => [ 4, "e",  "g",  nil                  ],  # float32
    0x89 => [ 8, "E",  "G",  nil                  ],  # float64
    0x0A => [ 1, "C",  "C",  0x00                 ],  # uint8z
    0x8B => [ 2, "S<", "S>", 0x0000               ],  # uint16z
    0x8C => [ 4, "L<", "L>", 0x00000000           ],  # uint32z
    0x0D => [ 1, "C",  "C",  0xFF                 ],  # byte
    0x8E => [ 8, "q<", "q>", 0x7FFFFFFFFFFFFFFF   ],  # sint64
    0x8F => [ 8, "Q<", "Q>", 0xFFFFFFFFFFFFFFFF   ],  # uint64
    0x90 => [ 8, "Q<", "Q>", 0x0000000000000000   ],  # uint64z
  }.freeze

  # Manufacturer id → brand name (most common devices)
  MANUFACTURERS = {
    1   => "Garmin",
    32  => "Wahoo",
    38  => "Pioneer",
    48  => "Polar",
    68  => "Stages",
    76  => "Suunto",
    89  => "Decathlon",
    92  => "Coros",
    255 => nil,    # invalid / development
  }.freeze

  # FIT sport enum → our activity_type strings
  SPORT_TYPES = {
    0  => "workout",           # generic
    1  => "running",
    2  => "cycling",
    4  => "workout",           # fitness_equipment
    5  => "swim",
    6  => "basketball",
    7  => "soccer",
    8  => "tennis",
    10 => "workout",           # training
    11 => "walking",
    12 => "nordic_ski",        # cross_country_skiing
    13 => "alpine_ski",
    14 => "snowboard",
    15 => "rowing",
    17 => "hiking",            # mountaineering
    19 => "hiking",
    21 => "workout",           # multisport
    37 => "stand_up_paddling",
    41 => "yoga",
    46 => "virtual_ride",      # e-cycling
  }.freeze
end
