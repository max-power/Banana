class Current < ActiveSupport::CurrentAttributes
  # attribute :session
  # attribute :user_agent, :ip_address

  # delegate :user, to: :session, allow_nil: true

  # def theme
  #   user&.preferred_theme
  # end
  #
  def user
      @user ||= User.find_or_create_by(email: "anselm@holthaus.de")
      #@user ||= User.find_or_create_by(email: "kevin@melchert.xyz")
  end
end
