class RefreshMvtViewJob < ApplicationJob
    queue_as :default

    def perform
        # 'concurrently: true' allows the map to stay visible during the refresh
        # This only works if you added the unique index above!
        ActivitySegmentsMvt.refresh(concurrently: true)
    end
end
