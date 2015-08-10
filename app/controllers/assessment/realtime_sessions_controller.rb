class Assessment::RealtimeSessionsController < ApplicationController
  load_and_authorize_resource :course
  load_and_authorize_resource :realtime_session_group, class: "Assessment::RealtimeSessionGroup", through: :course
  load_and_authorize_resource :realtime_session, class: "Assessment::RealtimeSession"

  #load_and_authorize_resource :assessment_realtime_training, class: "Assessment::RealtimeTraining", through: :course
  #load_and_authorize_resource :realtime_session, class: "Assessment::RealtimeSession", through: :realtime_training
  before_filter :load_general_course_data, only: [:start_session]

  def finalize_grade_training
    #TODO: REFACRORING - update grade for all student on table
    #finalize all submission first
    sms = @realtime_session.realtime_session_group.training.submissions.belong_to_stds(@realtime_session.student_seats.map{|s| s.std_course_id })
    sms.each do |sm|
      sm.update_grade
    end
    (1..@realtime_session.number_of_table).each_with_index do |t,i|
      session_students = @realtime_session.get_student_seats_by_table(t).has_student
      total_grade = 0
      sm_list = {}
      no_sm_count = 0

      #update team grade and exp
      session_students.each do |ss|
        sm = ss.student.submissions.where(assessment_id: @realtime_session.realtime_session_group.training.assessment.id).last
        no_sm_count+=1 if sm.nil?
        total_grade = total_grade + (sm.nil? ? 0 : (sm.gradings.last.nil? ? 0 : (sm.gradings.last.grade.nil? ? 0 : sm.gradings.last.grade)))
        sm_list[ss.id] = sm
      end
      session_students.each do |ss|
        if !sm_list[ss.id].nil?
          ss.update_attribute(:team_grade, total_grade/(session_students.count-no_sm_count))
          asm = sm_list[ss.id].assessment
          grading = sm_list[ss.id].get_final_grading
          unless grading.exp_transaction
            grading.exp_transaction = ExpTransaction.create({giver_id: sm_list[ss.id].get_final_grading.grader_id,
                                                  user_course_id: ss.student.id,
                                                  reason: "Exp for #{asm.title}",
                                                  is_valid: true,
                                                  rewardable_id: sm_list[ss.id].id,
                                                  rewardable_type: sm_list[ss.id].class.name },
                                                 without_protection: true)
            grading.save
          end

          grading.exp_transaction.exp = asm.max_grade.nil? ? 0 : (total_grade/(session_students.count-no_sm_count) || 0) * asm.exp / asm.max_grade
          grading.exp_transaction.save
        end

      end
    end

    #TODO: Check for Refactoring for performance (maybe use scope no submission in usercourse)
    #set grade 0 to missing students
    @realtime_session.students.each do |s|
      if s.submissions.where(assessment_id: @realtime_session.realtime_session_group.training.assessment.id).last.nil?
        sub = @realtime_session.realtime_session_group.training.submissions.create(std_course_id: s.id)
        sub.set_graded
        sub.gradings.create({grade: 0, std_course_id: s.id})
      end
    end

    @realtime_session.reset
    flash[:notice] = "Grade finalization is done!"
    redirect_to :back
  end

  def start_session
    if params[:t] == "training"
      @realtime_session.reset
      @realtime_training = @realtime_session.realtime_session_group.training
      authorize! :manage, @realtime_training
      @realtime_session.update_attribute(:status, true)
      @session = @realtime_session

    end
  end

  def switch_lock_question
    session_question = Assessment::RealtimeSessionQuestion.find(params[:session_question_id])
    session[:sq_update_time] = session_question.updated_at if session_question.unlock
    session_question.unlock_count = session_question.unlock_count + 1 if !session_question.unlock
    session_question.unlock = session_question.unlock? ? false : true;
    respond_to do |format|
      if session_question.save
        session[:sq_update_time] = session_question.updated_at if session_question.unlock
        format.json { render json: { result: true, u_c: session_question.unlock_count}}
      else
        format.json { render json: { result: false}}
      end
    end
  end

  def count_submission
    session_question = Assessment::RealtimeSessionQuestion.find(params[:session_question_id])
    question_answers = session_question.question_assessment.question.answers.
        in_student_list(@realtime_session.student_seats.map{|s| s.std_course_id }).
        in_submission_list(@realtime_session.realtime_session_group.training.assessment.submissions.map{|s| s.id }).
        after_question_unlock(session_question)

    #question_answers = @realtime_session.realtime_training.submissions.answers.in_list(@realtime_session.student_seats.map{|s| s.std_course_id })
    respond_to do |format|
      format.json { render json: { count: question_answers.count}}
    end
  end

  def answers_stats
    session_question = Assessment::RealtimeSessionQuestion.find(params[:session_question_id])
    question = session_question.question_assessment.question
    answers = question.answers.in_student_list(@realtime_session.student_seats.map{|s| s.std_course_id }).
        in_submission_list(@realtime_session.realtime_session_group.training.assessment.submissions.map{|s| s.id }).
        after_unlock_time(session[:sq_update_time])

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

  def reattempt_next_unlock

  end
end
