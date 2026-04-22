class Session < ApplicationRecord
  belongs_to :user

  has_secure_token

  def touch_last_active!
    touch(:last_active_at)
  end
end
