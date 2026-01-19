class Tour < Activity
    has_many :activities, -> { order(:start_time) }, foreign_key: :tour_id, dependent: :nullify

    def time_period
        TimePeriod.new(start_time, end_time)
    end

    def distance
        activities.sum(:distance)
    end

    def moving_time
        activities.sum(:moving_time)
    end

    def elapsed_time
        activities.sum(:elapsed_time)
    end

    def elevation_gain
        activities.sum(:elevation_gain)
    end

    def average_speed
        activities.average(:average_speed)
    end

    def add_activity(activity)
        activities << activity
    end

    def start_time
        activities.first&.start_time
    end

    def end_time
        activities.last&.end_time
    end

    def track
        #   track__
        JSON.parse(combined_track["combined_track"])
    end

    def bbox
        JSON.parse(combined_track["bbox"])
    end

    def track__
        #activities.map(&:track)
        tracks = activities.order(:start_time).map(&:track)

        factory = RGeo::Cartesian.factory
        collection = factory.collection(tracks)

        if collection.respond_to?(:line_merge)
        # If using RGeo with PostGIS adapter
            collection.line_merge
        else
        # If direct merge not available, we can return the collection
        collection
        end
    end

    def combined_track
        # Get all activities in order
        activity_ids = activities.order(:start_time).pluck(:id)
        return nil if activity_ids.empty?

        # Use PostGIS functions but let the database handle the geometry conversions
        result = ActiveRecord::Base.connection.execute(<<-SQL)
        SELECT
        --ST_AsGeoJSON(ST_LineMerge(ST_Collect(track::geometry))) AS combined_track,
        ST_AsGeoJSON(ST_Collect(track::geometry)) as combined_track,
        ST_AsGeoJSON(ST_Envelope(ST_Collect(track::geometry))) AS bbox
        --         ST_AsSVG(ST_Collect(track::geometry)) AS svg_path
        FROM activities
        WHERE id IN (#{activity_ids.join(',')})
        SQL
        result.first
    end


    # WITH aggregated_track AS (
    #   SELECT ST_Collect(track::geometry) AS geom
    #   FROM activities
    #   WHERE id IN (#{activity_ids.join(',')})
    # ),
    # dumped_lines AS (
    #   SELECT (ST_Dump(ST_LineMerge(geom))).geom AS line_geom
    #   FROM aggregated_track
    # )
    # SELECT string_agg(ST_AsEncodedPolyline(line_geom), '') AS encoded_polyline
    # FROM dumped_lines;


    def generate_combined_track!
        combined_wkt = combined_track

        if combined_wkt.present?
        # Use update_column to avoid callbacks
        # This assumes your model has a setter that handles WKT conversion
            self.tracks = combined_wkt
            self.save
        end
    end
end
