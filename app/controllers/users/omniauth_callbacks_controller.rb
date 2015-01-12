class Users::OmniauthCallbacksController < Devise::OmniauthCallbacksController
  def facebook
    # If a user is signed in then he is trying to link a new account
    if user_signed_in?
      auth = request.env["omniauth.auth"]
      if current_user && current_user.persisted? && current_user.update_external_account(auth)
        flash[:success] = "Your facebook account has been linked to this user account successfully."
      else
        flash[:error] = "The Facebook account has been linked with another user."
      end
      redirect_to edit_user_path(current_user)
    else
      @user = User.find_for_facebook_oauth(request.env["omniauth.auth"], current_user)
      if @user.persisted?
        sign_in_and_redirect @user, :event => :authentication #this will throw if @user is not activated
        set_flash_message(:notice, :success, :kind => "Facebook") if is_navigational_format?
      else
        session["devise.facebook_data"] = request.env["omniauth.auth"]
        redirect_to new_user_registration_url
      end
    end
  end

  def ivle

    if user_signed_in?
      auth = request.env["omniauth.auth"]
      if current_user && current_user.persisted? && current_user.update_external_account(auth)
        flash[:success] = "Your ivle account has been linked to this user account successfully."
      else
        flash[:error] = "The ivle account has been linked with another user."
      end
      redirect_to edit_user_path(current_user)
    else
      @user = User.find_for_ivle_oauth(request.env["omniauth.auth"], current_user)
      if @user.persisted?
        session["ivle_login_data"] = request.env["omniauth.auth"]
        sign_in_and_redirect @user, :event => :authentication #this will throw if @user is not activated
        set_flash_message(:notice, :success, :kind => "Ivle") if is_navigational_format?
      else
        redirect_to new_user_registration_url
      end
    end
  end

  def open_id
    if user_signed_in?
      auth = request.env["omniauth.auth"]
      if current_user && current_user.persisted? && current_user.update_external_account(auth)
        flash[:success] = "Your nus openid account has been linked to this user account successfully."
      else
        flash[:error] = "The nus openid account has been linked with another user."
      end
      redirect_to edit_user_path(current_user)
    else
      @user = User.find_for_openid_oauth(request.env["omniauth.auth"], current_user)
      if @user.persisted?
        sign_in_and_redirect @user, :event => :authentication #this will throw if @user is not activated
        set_flash_message(:notice, :success, :kind => "NUS OpenID") if is_navigational_format?
      else
        redirect_to new_user_registration_url
      end
    end
  end


end
