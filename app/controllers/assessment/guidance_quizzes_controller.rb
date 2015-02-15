class Assessment::GuidanceQuizzesController < ApplicationController
  load_and_authorize_resource :course
  load_and_authorize_resource :assessment, only: [:access_denied]
  before_filter :load_general_course_data, only: [:access_denied]


  #Only one guidance assessment per course, hence 
  #we use a collection method to constantly access it
  def set_enabled
    enabled = params[:enable]

    if enabled == "true"
		  Assessment::GuidanceQuiz.enable(@course)
    else
      Assessment::GuidanceQuiz.disable(@course)
    end
    
    respond_to do |format| 
      format.json { render json: { result: true}}
    end
  end

  def access_denied

  end
end
