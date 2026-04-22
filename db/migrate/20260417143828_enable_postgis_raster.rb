class EnablePostgisRaster < ActiveRecord::Migration[8.1]
  def change
    enable_extension "postgis_raster"
  end
end
