require "omniauth"
require "faraday"
require "multi_json"

class StaticPagesController < ApplicationController
  def welcome
    #@courses = Course.online_course.limit(10)
    t = 0
    token = request.params["token"]
    unless token.nil?
      profile_url = "https://ivle.nus.edu.sg/api/Lapi.svc/Profile_View?APIKey=mHy1mEcwwWvlHYqc9bNdO&AuthToken=#{token}"

      #conn = Faraday::Connection.new(url: profile_url, :ssl => { :ca_path => "/usr/local/ssl/certs"})
      conn = Faraday.new(url: profile_url, ssl: { verify: false })
      #conn = Faraday.new(url: profile_url)
      response = conn.get
      logger.debug "response body #{response.body}"
      json = MultiJson.decode(response.body)
      @profile = json["Results"][0]
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
    else
      respond_to do |format|
        format.html
        format.json { render json: { access_denied: flash[:alert] }}
      end
    end
  end
end
