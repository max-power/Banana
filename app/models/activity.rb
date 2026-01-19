class Activity < ApplicationRecord
    belongs_to :user
    has_one_attached :file #, service: :local, analyzable: true

    scope :chronologically, -> { order(:start_time, :id) }
    scope :reverse_chronologically, -> { order(start_time: :desc, id: :desc) }
    scope :within_time_range, ->(range) { where(start_time: (range.begin..range.end)) }

    after_touch :sync_metadata_from_file

    scope :with_geojson, ->(tolerance = 0.0001) {
        select(arel_table[Arel.star]) # Select all original columns
            .select("ST_AsGeoJSON(ST_Simplify(track::geometry, #{connection.quote(tolerance)})) AS geojson_path")
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

        # Extract data from the blob's metadata hash
        meta = file.blob.metadata

        if meta[:coordinates].present?
            rgeo_points = meta[:coordinates].map { |lat, lon, ele| Geo.point(lon, lat, ele) }
        end

        update_columns(
            name:           meta[:activity_name],
            activity_type:  meta[:activity_type],
            distance:       meta[:distance_m],
            elevation_gain: meta[:elevation_gain_m],
            start_time:     (Time.at(meta[:time_start]) if meta[:time_start]),
            end_time:       (Time.at(meta[:end_time]) if meta[:end_time]),
            moving_time:    meta[:time_moving_s],
            elapsed_time:   meta[:time_elapsed_s],
            # average_speed:  meta[:elevation_gain_m],
            track:          Geo.line_string(rgeo_points)
        )
    end
end


# def simplified_geojson(precision = 0.0001)
#   # path::geometry converts from 'geography' to 'geometry' for the function
#   self.class.where(id: id)
#             .select("ST_AsGeoJSON(ST_Simplify(path::geometry, #{precision})) as geo")
#             .first.geo_path
# end

# private

# def gpx_file_format
#   return unless gpx_file.attached?
#   unless gpx_file.content_type == Mime[:gpx]
#     errors.add(:gpx_file, 'must be a GPX file')
#   end
# end
