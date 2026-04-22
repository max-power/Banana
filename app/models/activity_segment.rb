class ActivitySegment < ApplicationRecord
  belongs_to :activity

  # Optional scopes
  scope :for_user, ->(user_id) {
    joins(:activity).where(activities: { user_id: user_id })
  }

  scope :polyline, -> {
    select("ST_AsEncodedPolyline(ST_LineMerge(ST_Collect(geom))) as polyline")
  }

end
