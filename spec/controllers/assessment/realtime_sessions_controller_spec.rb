require 'spec_helper'

describe Assessment::RealtimeSessionsController do

  describe "GET 'start_session'" do
    it "returns http success" do
      get 'start_session'
      response.should be_success
    end
  end

end
