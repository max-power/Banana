class Session < ApplicationRecord
  belongs_to :user

  has_secure_token

  def touch_last_active!
    update_column(:last_active_at, Time.current)
  end
end
