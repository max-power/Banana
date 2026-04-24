class TourMembership < ApplicationRecord
  belongs_to :tour
  belongs_to :activity
end
