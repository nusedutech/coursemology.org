class Assessment::RealtimeTrainingSessionsController < ApplicationController
  load_and_authorize_resource :course
  load_and_authorize_resource :realtime_training, class: "Assessment::RealtimeTraining", through: :course
  #load_and_authorize_resource :realtime_training_session, class: "Assessment::RealtimeTrainingSession", through: :realtime_training
  before_filter :load_general_course_data, only: [:start_session]

  def start_session
    @realtime_training = @course.realtime_trainings.find(params[:assessment_realtime_training_id])
    authorize! :manage, @realtime_training
    @session = @realtime_training.sessions.find(params[:id])
  end

  def switch_lock_question
    session_question = Assessment::RealtimeTrainingSessionQuestion.find(params[:session_question_id])
    session_question.unlock = session_question.unlock? ? false : true;
    respond_to do |format|
      format.json { render json: { result: true}}
    end
  end

  def count_submission
    session_question = Assessment::RealtimeTrainingSessionQuestion.find(params[:session_question_id])

    respond_to do |format|
      format.json { render json: { count: session_question.question_assessment.question.answers.count}}
    end
  end

end
