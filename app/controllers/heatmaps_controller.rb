class HeatmapsController < ApplicationController
  before_action :authenticate!

  def show
    uid = ActiveRecord::Base.connection.quote(Current.user.id)

    result = ActiveRecord::Base.connection.exec_query(<<~SQL, "heatmap_bounds")
      SELECT
        ST_XMin(ST_Extent(ST_Transform(s.geom, 4326))) AS lon_min,
        ST_YMin(ST_Extent(ST_Transform(s.geom, 4326))) AS lat_min,
        ST_XMax(ST_Extent(ST_Transform(s.geom, 4326))) AS lon_max,
        ST_YMax(ST_Extent(ST_Transform(s.geom, 4326))) AS lat_max
      FROM activity_segments s
      JOIN activities a ON a.id = s.activity_id
      WHERE a.user_id = #{uid}
      AND a.type IS NULL
    SQL

    row = result.rows.first
    @bounds = row&.all? ? row.map(&:to_f) : nil

    @years = ActiveRecord::Base.connection.exec_query(<<~SQL, "heatmap_years")
      SELECT DISTINCT EXTRACT(YEAR FROM start_time)::int AS year
      FROM activities
      WHERE user_id = #{uid}
      AND type IS NULL
      AND start_time IS NOT NULL
      ORDER BY year DESC
    SQL
    .rows.flatten.map(&:to_i)
  end
end
