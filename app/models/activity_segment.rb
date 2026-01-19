class ActivitySegment < ApplicationRecord
    belongs_to :activity

    # Optional scopes
    scope :for_user, ->(user_id) {
        joins(:activity).where(activities: { user_id: user_id })
    }

    after_commit :refresh_scenic_view

    def refresh_scenic_view
      # Use 'CONCURRENTLY' so the view stays readable during the update
      # (Requires a unique index on the materialized view)
      #ActiveRecord::Base.connection.execute("REFRESH MATERIALIZED VIEW CONCURRENTLY scenic_view_cached")
    end
end
