class User < ApplicationRecord
  has_many :activities, dependent: :destroy
  has_many :sessions, dependent: :destroy

  generates_token_for :magic_link, expires_in: 15.minutes
end
