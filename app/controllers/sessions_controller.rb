class SessionsController < ApplicationController
  def new
    redirect_to root_path if authenticated?
  end

  def destroy
    terminate_session
    redirect_to new_session_path, notice: "You've been signed out."
  end
end
