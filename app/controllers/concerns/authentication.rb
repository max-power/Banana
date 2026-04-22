module Authentication
    extend ActiveSupport::Concern

    included do
        before_action :set_current_request_details
        helper_method :current_user, :authenticated?
    end

    def current_user
        Current.user
    end

    def authenticated?
        current_user.present?
    end

    def authenticate!
        authenticated? || request_authentication
    end

    def request_authentication
        if request.format.html?
            session[:return_to] = request.url
            redirect_to new_session_path
        else
            head :unauthorized
        end
    end

    def after_authentication_url
        session.delete(:return_to) || root_url
    end

    def start_new_session_for(user)
        user.sessions.create!(user_agent: request.user_agent, ip_address: request.ip).tap do |s|
            Current.session = s
            cookies.encrypted.permanent[:session_token] = {
                value: s.token,
                httponly: true,
                same_site: :lax
            }
        end
    end

    def terminate_session
        Current.session&.destroy
        cookies.delete(:session_token)
    end

    private

    def set_current_request_details
        Current.user_agent = request.user_agent
        Current.ip_address = request.ip
        Current.session = find_session_from_cookie
    end

    def find_session_from_cookie
        token = cookies.encrypted[:session_token]
        return unless token

        Session.find_by(token: token)&.tap do |s|
            # Only touch last-active for full browser page loads, not asset/API requests
            next unless request.format.html?
            s.touch_last_active! if s.last_active_at.nil? || s.last_active_at < 5.minutes.ago
        end
    end
end
