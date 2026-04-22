class MagicLinksController < ApplicationController
    def create
        user = User.find_by(email: params[:email].to_s.downcase.strip)

        if user
            token = user.generate_token_for(:magic_link)
            AuthenticationMailer.magic_link(user, token).deliver_later
        end

        # Same message regardless of whether email exists — prevents enumeration
        redirect_to new_session_path, notice: "If that email is registered, a sign-in link is on its way."
    end

    def verify
        user = User.find_by_token_for(:magic_link, params[:token])

        if user
            user.update_column(:verified_at, Time.current) unless user.verified_at?
            start_new_session_for(user)
            redirect_to after_authentication_url, notice: "Welcome!"
        else
            redirect_to new_session_path, alert: "That link has expired or is invalid. Please request a new one."
        end
    end
end
