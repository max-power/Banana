class HeatmapsController < ApplicationController
  before_action :authenticate!

  def show
    uid = Current.user.id

    result = ActiveRecord::Base.connection.exec_query(<<~SQL, "heatmap_bounds", [ uid ])
      SELECT
        ST_XMin(ST_Extent(ST_Transform(s.geom, 4326))) AS lon_min,
        ST_YMin(ST_Extent(ST_Transform(s.geom, 4326))) AS lat_min,
        ST_XMax(ST_Extent(ST_Transform(s.geom, 4326))) AS lon_max,
        ST_YMax(ST_Extent(ST_Transform(s.geom, 4326))) AS lat_max
      FROM activity_segments s
      JOIN activities a ON a.id = s.activity_id
      WHERE a.user_id = $1
      AND a.type IS NULL
    SQL

    row = result.rows.first
    @bounds = row&.all? ? row.map(&:to_f) : nil

    @years = ActiveRecord::Base.connection.exec_query(<<~SQL, "heatmap_years", [ uid ])
      SELECT DISTINCT EXTRACT(YEAR FROM start_time)::int AS year
      FROM activities
      WHERE user_id = $1
      AND type IS NULL
      AND start_time IS NOT NULL
      ORDER BY year DESC
    SQL
    .rows.flatten.map(&:to_i)

    @types = Current.user.activities.where(type: nil)
                    .where.not(activity_type: nil)
                    .distinct.pluck(:activity_type).sort
  end
end
