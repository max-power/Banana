class HeatmapPalette
  # Stops: [count, [R, G, B, A]]
  # count 0 = no activity (transparent)
  # count 1 = first visible pixel (single ride)
  # count 10 = saturated (regular route)
  # count 50+ = blown out to white (very frequent route)
  DEFINITIONS = {
    "purple" => { label: "Purple", stops: [ [0, [0,0,0,0]],       [1, [85,0,245,100]],    [10, [85,0,245,255]],       [50, [255,255,255,255]] ] },
    "hot"    => { label: "Hot",    stops: [ [0, [0,0,0,0]],       [1, [63,94,251,255]],   [10, [252,70,107,255]],     [50, [255,255,255,255]] ] },
    "orange" => { label: "Orange", stops: [ [0, [0,0,0,0]],       [1, [252,74,26,255]],   [10, [247,183,51,255]],     [50, [255,255,255,255]] ] },
    "red"    => { label: "Red",    stops: [ [0, [0,0,0,0]],       [1, [178,10,44,255]],   [10, [255,251,213,255]],    [50, [255,255,255,255]] ] },
    "pink"   => { label: "Pink",   stops: [ [0, [0,0,0,0]],       [1, [255,177,255,127]], [10, [255,177,255,255]],    [50, [255,255,255,255]] ] },
    "cyber"  => { label: "Cyber",  stops: [ [0, [0,0,0,0]],       [1, [0,255,65,180]],    [10, [0,255,65,255]],       [30, [180,255,0,255]],  [50, [255,255,200,255]] ] },
  }.freeze

  DEFAULT = "orange"

  attr_reader :id, :label

  def self.find(id)
    defn = DEFINITIONS[id] || DEFINITIONS[DEFAULT]
    new(**defn, id: id)
  end

  def self.all
    DEFINITIONS.map { |id, defn| new(**defn, id: id) }
  end

  def initialize(id:, label:, stops:)
    @id      = id
    @label   = label
    @palette = build(stops)
  end

  def [](count)
    @palette[count.clamp(0, 255)]
  end

  private

  def build(stops)
    palette = Array.new(256) { [0, 0, 0, 0] }

    stops.each_cons(2) do |(i0, c0), (i1, c1)|
      (i0..i1).each do |i|
        t = (i - i0).to_f / (i1 - i0)
        palette[i] = c0.zip(c1).map { |a, b| (a * (1.0 - t) + b * t).round }
      end
    end

    last_i, last_c = stops.last
    (last_i..255).each { |i| palette[i] = last_c }

    palette
  end
end
