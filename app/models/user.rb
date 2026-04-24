class User < ApplicationRecord
  has_many :activities, dependent: :destroy
  has_many :sessions, dependent: :destroy

  has_secure_password

  normalizes :email, with: -> e { e.strip.downcase }
  validates :email, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :password, length: { minimum: 8 }, allow_nil: true
end
