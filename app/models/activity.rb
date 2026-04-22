class Activity < ApplicationRecord
  belongs_to :user
  belongs_to :duplicate_of, class_name: "Activity", optional: true
  belongs_to :tour, optional: true
  has_one_attached :file #, service: :local, analyzable: true
  has_many :segments, class_name: "ActivitySegment", dependent: :destroy
  has_many :tiles,    class_name: "ActivityTile",    dependent: :destroy
  has_secure_token :share_token

  scope :chronologically, -> { order(:start_time, :id) }
  scope :reverse_chronologically, -> { order(start_time: :desc, id: :desc) }
  scope :within_time_range, ->(range) { where(start_time: (range.begin..range.end)) }
  scope :matching, ->(q) { where("name ILIKE ?", "%#{sanitize_sql_like(q)}%") }

  after_touch :sync_metadata_from_file

  scope :with_geojson, ->(tolerance = 0.0001) {
    select(arel_table[Arel.star])
    .select(
      <<~SQL.squish
      ST_AsGeoJSON(
        ST_Simplify(
          ST_Collect(activity_segments.geom ORDER BY activity_segments.segment_index),
          #{connection.quote(tolerance)}
        )
      ) AS geojson_path
      SQL
    )
    .left_joins(:segments)
    .group("#{table_name}.id")
  }

  scope :with_map_geojson, ->(tolerance = 50) {
    select(arel_table[Arel.star])
    .select("ST_AsGeoJSON(ST_Simplify(track_3857, #{connection.quote(tolerance)})) AS geojson_path")
  }


  def map_endpoints
    row = self.class.connection.exec_query(<<~SQL, "map_endpoints", [ id ]).first
      SELECT
        ST_AsGeoJSON(ST_StartPoint(
          (SELECT geom FROM activity_segments WHERE activity_id = $1 ORDER BY segment_index ASC LIMIT 1)
        )) AS start_coord,
        ST_AsGeoJSON(ST_EndPoint(
          (SELECT geom FROM activity_segments WHERE activity_id = $1 ORDER BY segment_index DESC LIMIT 1)
        )) AS end_coord
    SQL
    return [ nil, nil ] unless row
    [
      row["start_coord"] ? JSON.parse(row["start_coord"])["coordinates"] : nil,
      row["end_coord"]   ? JSON.parse(row["end_coord"])["coordinates"]   : nil,
    ]
  end

  # Returns [[west, south], [east, north]] in WGS-84, ready for MapLibre fitBounds.
  def bbox
    row = self.class.connection.exec_query(<<~SQL, "bbox", [ id ]).first
      SELECT ST_XMin(ext) AS west, ST_YMin(ext) AS south,
             ST_XMax(ext) AS east, ST_YMax(ext) AS north
      FROM (
        SELECT ST_Extent(geom)::geometry AS ext
        FROM activity_segments WHERE activity_id = $1
      ) s
    SQL
    return nil unless row && row["west"]
    [ [ row["west"], row["south"] ], [ row["east"], row["north"] ] ]
  end

  def full_polyline
    self.class.connection.exec_query(<<~SQL, "full_polyline", [ id ]).first&.dig("polyline")
      SELECT ST_AsEncodedPolyline(
        ST_MakeLine(dp.geom ORDER BY s.segment_index, (dp).path[1])
      ) AS polyline
      FROM activity_segments s,
           LATERAL ST_DumpPoints(s.geom) dp
      WHERE s.activity_id = $1
    SQL
  end


  private

  def sync_metadata_from_file(force: false)
    return unless file.attached? && (force || file.analyzed?)

    meta = file.blob.metadata

    update_columns(
      name:           meta[:activity_name],
      activity_type:  meta[:activity_type],
      distance:       meta[:distance_m],
      elevation_gain: meta[:elevation_gain_m],
      elevation_loss: meta[:elevation_loss_m],
      start_time:     (Time.at(meta[:time_start]) if meta[:time_start]),
      end_time:       (Time.at(meta[:time_end]) if meta[:time_end]),
      moving_time:    meta[:time_moving_s],
      elapsed_time:   meta[:time_elapsed_s],
      average_speed:  meta[:average_speed_m_s],
      max_speed:      meta[:max_speed_m_s],
      device:         meta[:device],
    )

    insert_segments(meta[:segments])
    update_track_3857
    check_for_duplicate
    ComputeActivityTilesJob.perform_later(id)
  end

  def check_for_duplicate
    return unless start_time && distance&.positive?

    match = user.activities
      .where.not(id: id)
      .where(start_time: (start_time - 2.minutes)..(start_time + 2.minutes))
      .where(distance: (distance * 0.98)..(distance * 1.02))
      .first

    update_column(:duplicate_of_id, match&.id)
  end

  def update_track_3857
    self.class.connection.exec_query(<<~SQL, "update_track_3857", [ id ])
      UPDATE activities
      SET track_3857 = (
        SELECT ST_Collect(geom_3857 ORDER BY segment_index)
        FROM activity_segments WHERE activity_id = $1
      )
      WHERE id = $1
    SQL
  end

  def insert_segments(segments_meta)
    # Delete old segments to avoid duplicates
    segments.delete_all

    segments_data = Array(segments_meta).map do |seg|
      coords  = seg[:coordinates].map { |lat, lon, ele| Geo.point(lon, lat, ele) }
      geom = Geo.line_string(coords) if coords.size > 1
      next unless geom # skip segments with < 2 points

      {
        activity_id:    id,
        segment_index:  seg[:index],
        start_time:     (Time.at(seg[:start_time]) if seg[:start_time]),
        end_time:       (Time.at(seg[:end_time]) if seg[:end_time]),
        distance_m:     seg[:distance_m],
        moving_time_s:  seg[:moving_time_s],
        geom:           geom,
        created_at:     Time.current,
        updated_at:     Time.current
      }
    end.compact

    ActivitySegment.insert_all!(segments_data) if segments_data.any?
  end
end
