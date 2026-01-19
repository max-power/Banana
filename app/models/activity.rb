class Activity < ApplicationRecord
    belongs_to :user
    has_one_attached :file #, service: :local, analyzable: true
    has_many :activity_segments, dependent: :destroy

    scope :chronologically, -> { order(:start_time, :id) }
    scope :reverse_chronologically, -> { order(start_time: :desc, id: :desc) }
    scope :within_time_range, ->(range) { where(start_time: (range.begin..range.end)) }

    after_touch :sync_metadata_from_file

    scope :with_geojson, ->(tolerance = 0.0001) {
      select(arel_table[Arel.star])
        .select(
          <<~SQL.squish
            ST_AsGeoJSON(
                ST_Simplify(
                  ST_LineMerge(ST_Collect(activity_segments.geom)),
                  #{connection.quote(tolerance)}
                )
            ) AS geojson_path
          SQL
        )
        .joins(:activity_segments)
        .group("#{table_name}.id")
    }


    #  scope :tours, -> { where.not(tour_id: nil) }

    # scope :within_bounds, ->(bounds) {
    #   where(latitude: bounds[:min_lat]..bounds[:max_lat],
    #   longitude: bounds[:min_lon]..bounds[:max_lon])
    # }

    #  validates :name, presence: true
    #  validates :file, presence: true,
    #    content_type: ['application/gpx+xml', 'application/xml', 'text/xml'],
    #    size: { less_than: 10.megabytes }

    def bbox
        RGeo::Cartesian::BoundingBox.new(Geo.factory).add(track).to_geometry
    end

    def distance_in_meters
        track&.length || 0
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
            start_time:     Time.at(meta[:time_start]),
            end_time:       Time.at(meta[:time_end]),
            moving_time:    meta[:time_moving_s],
            elapsed_time:   meta[:time_elapsed_s],
        )

        insert_segments_from_gpx(meta[:segments])
    end

    def insert_segments_from_gpx(segments_meta)
        # Delete old segments to avoid duplicates
        activity_segments.delete_all

        segments_data = Array(segments_meta).map do |seg|
            coords  = seg[:coordinates].map { |lat, lon, ele| Geo.point(lon, lat, ele) }
            geom = Geo.line_string(coords) if coords.size > 1
            next unless geom # skip segments with < 2 points

            {
                activity_id:    id,
                segment_index:  seg[:index],
                start_time:     Time.at(seg[:start_time]),
                end_time:       Time.at(seg[:end_time]),
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
