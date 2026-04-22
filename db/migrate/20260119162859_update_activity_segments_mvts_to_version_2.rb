class UpdateActivitySegmentsMvtsToVersion2 < ActiveRecord::Migration[8.1]
  def change
    update_view :activity_segments_mvts, version: 2, revert_to_version: 1, materialized: true
  end
end
