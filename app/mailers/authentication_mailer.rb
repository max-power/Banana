class AuthenticationMailer < ApplicationMailer
  def magic_link(user, token)
    @user = user
    @magic_link_url = verify_magic_link_url(token: token)
    mail(to: user.email, subject: "Your sign-in link")
  end
end
