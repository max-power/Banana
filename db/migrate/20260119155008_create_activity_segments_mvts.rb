class CreateActivitySegmentsMvts < ActiveRecord::Migration[8.1]
  def change
    create_view :activity_segments_mvts, materialized: true
  end
end
