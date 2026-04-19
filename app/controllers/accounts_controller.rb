class AccountsController < ApplicationController
  before_action :authenticate!

  def show
  end

  def update
    if Current.user.update(account_params)
      redirect_to account_path, notice: "Settings saved."
    else
      render :show, status: :unprocessable_entity
    end
  end

  private

  def account_params
    params.require(:user).permit(:public_profile)
  end
end
