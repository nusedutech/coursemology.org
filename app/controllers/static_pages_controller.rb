class StaticPagesController < ApplicationController
  def welcome
    #@courses = Course.online_course.limit(10)
  end

  def get_profile
    @token = params[:token]
  end
  def ivle

    # If a user is signed in then he is trying to link a new account
    if user_signed_in?
      #auth = request.env["omniauth.auth"]
      #if current_user && current_user.persisted? && current_user.update_external_account(auth)
      #  flash[:success] = "Your facebook account has been linked to this user account successfully."
      #else
      #  flash[:error] = "The Facebook account has been linked with another user."
      #end
      #redirect_to edit_user_path(current_user)
    else
      token = params[:token]
      email = params[:email]
      #recent_posts = HTTParty.get "https://ivle.nus.edu.sg/api/Lapi.svc/Profile_View?APIKey=mHy1mEcwwWvlHYqc9bNdO&AuthToken=#{token}"
      #puts recent_posts.status, recent_posts.count

      @user = User.find_for_ivle_oauth(email)
      sign_in_and_redirect @user, :event => :authentication #this will throw if @user is not activated
      set_flash_message(:notice, :success, :kind => "Facebook") if is_navigational_format?

    end
  end

  def about
  end

  def privacy_policy
  end

  def contact_us

  end

  def help

  end

  def access_denied
    if current_user && session[:request_url] && request.url == access_denied_url && session[:request_url] != request.url
      url = session[:request_url]
      session[:request_url] = nil
      redirect_to url
    end
  end
end
