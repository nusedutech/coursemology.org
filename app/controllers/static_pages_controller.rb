require "omniauth"
require "faraday"
require "multi_json"

class StaticPagesController < ApplicationController
  def welcome

    profile_url = "https://ivle.nus.edu.sg/api/Lapi.svc/Profile_View?APIKey=mHy1mEcwwWvlHYqc9bNdO&AuthToken=D1C62D2BFA2C4B87EEDC325429E8B902329702D0317E0FB0FA0444EA861A96A28DE8620E51E447CDA7CA79B85EA12D3ACFA00C62E3951994C57797F3EB588117752D42FD7E1C85E2DB29DF4928658CB4407101086FFC2FF4888541E960C806B7C5E1251D681B6715141AEDB313775537636FFF1A9EE8F7205A6D31002328B5A9BBE60F180CCF95A24808FB51ABFAD3580CF38098990B3A33F367A505D2FF224CC61EF849A8867A4F6CA61C40D4A73F2DC2766A9DF1384A2475DBC2BC65C4D4400A4E1B4FF23C8E10CAC32906AEEE52FEA92AA111A3A70079F2CFAEE087D66EA6C7C5A603241D144EE5E0B712E6AEE6DF"
    response = HTTParty.get(profile_url)
    logger.debug "response body2 #{response.body}"
    json = MultiJson.decode(response.body)
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
