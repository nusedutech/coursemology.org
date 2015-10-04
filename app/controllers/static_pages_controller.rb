require "omniauth"
require "faraday"
require "multi_json"

class StaticPagesController < ApplicationController
  def welcome

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
    else
      respond_to do |format|
        format.html
        format.json { render json: { access_denied: flash[:alert] }}
      end
    end
  end
end
