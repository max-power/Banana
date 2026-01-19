class ActivitySegment < ApplicationRecord
    belongs_to :activity

    # Optional scopes
    scope :for_user, ->(user_id) {
        joins(:activity).where(activities: { user_id: user_id })
    }

    # move to import job
    # after_commit :refresh_map_tiles, on: [:create, :update]

    # private

    # def refresh_map_tiles
    #     RefreshMvtViewJob.perform_later
    # end
end
