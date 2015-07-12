class Assessment::RealtimeTrainingSessionsController < ApplicationController
  load_and_authorize_resource :course
  load_and_authorize_resource :realtime_training, class: "Assessment::RealtimeTraining", through: :course
  load_and_authorize_resource :realtime_training_session, class: "Assessment::RealtimeTrainingSession"

  #load_and_authorize_resource :assessment_realtime_training, class: "Assessment::RealtimeTraining", through: :course
  #load_and_authorize_resource :realtime_training_session, class: "Assessment::RealtimeTrainingSession", through: :realtime_training
  before_filter :load_general_course_data, only: [:start_session]

  def finalize_grade
    #TODO: REFACRORING - update grade for all student on table
    (1..@realtime_training_session.number_of_table).each_with_index do |t,i|
      students = @realtime_training_session.get_student_seats_by_table(t)
      total_grade = 0
      students.each do |s|
        sm = s.student.submissions.where(assessment_id: @realtime_training_session.realtime_training.assessment.id).last
        total_grade = total_grade + (sm.nil? ? 0 : (sm.get_final_grading.nil? ? 0 : sm.get_final_grading.grade))
      end
      students.each do |s|
        s.update_attribute(:team_grade, total_grade/students.count)
      end
    end

    flash[:notice] = "Grade finalization is done!"
    redirect_to :back
  end

  def start_session
    @realtime_training = @realtime_training_session.realtime_training
    authorize! :manage, @realtime_training
    @realtime_training_session.update_attribute(:status, true)
    @session = @realtime_training_session
  end

  def switch_lock_question
    session_question = Assessment::RealtimeTrainingSessionQuestion.find(params[:session_question_id])
    session_question.unlock_count = session_question.unlock_count + 1 if !session_question.unlock
    session_question.unlock = session_question.unlock? ? false : true;
    respond_to do |format|
      if session_question.save
        format.json { render json: { result: true, u_c: session_question.unlock_count}}
      else
        format.json { render json: { result: false}}
      end
    end
  end

  def count_submission
    session_question = Assessment::RealtimeTrainingSessionQuestion.find(params[:session_question_id])
    question_answers = session_question.question_assessment.question.answers.
        in_student_list(@realtime_training_session.student_seats.map{|s| s.std_course_id }).
        in_submission_list(@realtime_training_session.realtime_training.assessment.submissions.map{|s| s.id })

    #question_answers = @realtime_training_session.realtime_training.submissions.answers.in_list(@realtime_training_session.student_seats.map{|s| s.std_course_id })
    respond_to do |format|
      format.json { render json: { count: question_answers.count}}
    end
  end

  def answers_stats
    session_question = Assessment::RealtimeTrainingSessionQuestion.find(params[:session_question_id])
    question = session_question.question_assessment.question
    answers = question.answers.in_list(@realtime_training_session.student_seats.map{|s| s.std_course_id })

    #TODO: Refactoring get list answers stats (can refer to stats page)
    @summary = {}
    question.as_question.options.each_with_index do |o,i|
      @summary["#{o.id}"] = 0
    end
    answers.each do |a|
      @summary["#{a.answer.options.first.id}"] = @summary["#{a.answer.options.first.id}"].nil? ? 1 : @summary["#{a.answer.options.first.id}"] + 1
    end

    respond_to do |format|
      format.json { render json: { result: @summary}}
    end
  end
end
