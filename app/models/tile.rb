Tile = Data.define(:z, :x, :y) do
  def cache_key
    "/#{z}/#{x}/#{y}"
  end
end
