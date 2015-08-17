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
          team_grade = total_grade/(session_students.count-no_sm_count)
          ss.update_attribute(:team_grade, team_grade)
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

          grading.exp_transaction.exp = asm.max_grade.nil? ? 0 : ((team_grade*25/100 + (grading.grade.nil? ? 0 : grading.grade)*75/100) || 0) * asm.exp / asm.max_grade
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

  def finalize_grade_mission
    #TODO: REFACRORING - update grade for all student on table
    #finalize all submission first
    sms = @realtime_session.realtime_session_group.mission.submissions.belong_to_stds(@realtime_session.student_seats.map{|s| s.std_course_id })
    sms.each do |sm|
      sm.update_grade
    end

    @realtime_session.reset
    flash[:notice] = "Finalization is done!"
    redirect_to :back
  end

  def start_session
    if params[:t] == "training"
      @realtime_session.reset
      @realtime_training = @realtime_session.realtime_session_group.training
      authorize! :manage, @realtime_training
      @realtime_session.update_attribute(:status, true)
      @session = @realtime_session
    elsif params[:t] == "mission"
      @realtime_session.reset
      @realtime_mission = @realtime_session.realtime_session_group.mission
      authorize! :manage, @realtime_mission
      @realtime_session.update_attribute(:status, true)
      @session = @realtime_session
    end
  end

  def switch_lock_question
    if params[:sub_question_id] and !params[:sub_question_id].empty?
      respond_to do |format|
        session_question = Assessment::RealtimeSessionQuestion.find(params[:session_question_id])
        unlock_flag = (params[:unlock]=='true') ? true : false
        if !unlock_flag and session_question.unlock_count == 0
          format.json { render json: { result: false}}
        else
          # Using unlock_count as temp variable for sub question unlock
          session_question.unlock_count = params[:sub_question_id] if unlock_flag
          session_question.unlock_time = Time.now if unlock_flag
          session_question.unlock = unlock_flag

          if session_question.save
            format.json { render json: { result: true, u_c: session_question.unlock_count}}
          else
            format.json { render json: { result: false}}
          end
        end
      end
    else
      respond_to do |format|
        session_question = Assessment::RealtimeSessionQuestion.find(params[:session_question_id])
        unlock_flag = (params[:unlock]=='true') ? true : false
        if !unlock_flag and session_question.unlock_count == 0
          format.json { render json: { result: false}}
        else
          #reset all session_question
          session_question.session.reset
          session_question.unlock_count = session_question.unlock_count + 1 if unlock_flag
          session_question.unlock_time = Time.now if unlock_flag
          session_question.unlock = unlock_flag
          if session_question.save
            format.json { render json: { result: true, u_c: session_question.unlock_count}}
          else
            format.json { render json: { result: false}}
          end
        end
      end
    end

  end

  def count_submission
    session_question = Assessment::RealtimeSessionQuestion.find(params[:session_question_id])
    asm = session_question.question_assessment.assessment
    if asm.is_mission?
      if params[:sub_question_id] and !params[:sub_question_id].empty?
        question_answers = Assessment::Question.find(params[:sub_question_id]).answers.general.
            in_student_list(@realtime_session.student_seats.map{|s| s.std_course_id }).
            in_submission_list(@realtime_session.realtime_session_group.mission.assessment.submissions.map{|s| s.id }).give_vote(session_question)

        respond_to do |format|
          format.json { render json: { count: question_answers.count}}
        end
      else
        question_answers = session_question.question_assessment.question.answers.general.
            in_student_list(@realtime_session.student_seats.map{|s| s.std_course_id }).
            in_submission_list(@realtime_session.realtime_session_group.mission.assessment.submissions.map{|s| s.id }).give_vote(session_question)

        #question_answers = @realtime_session.realtime_training.submissions.answers.in_list(@realtime_session.student_seats.map{|s| s.std_course_id })
        respond_to do |format|
          format.json { render json: { count: question_answers.count}}
        end
      end
    else
      question_answers = session_question.question_assessment.question.answers.
          in_student_list(@realtime_session.student_seats.map{|s| s.std_course_id }).
          in_submission_list(@realtime_session.realtime_session_group.training.assessment.submissions.map{|s| s.id }).
          after_question_unlock(session_question)

      answers_notcount_std_sbm = session_question.question_assessment.question.answers.
          after_question_unlock(session_question)

      #question_answers = @realtime_session.realtime_training.submissions.answers.in_list(@realtime_session.student_seats.map{|s| s.std_course_id })
      respond_to do |format|
        format.json { render json: { count: question_answers.count, info: "check submissions after unlock time #{session_question.unlock_time}, run at #{Time.now}"}}
        logger.debug "Do count_submission to check for submission updated after #{session_question.updated_at}, run at #{Time.now}, count_with_std_sbm #{question_answers.count},count_without_std_sbm #{answers_notcount_std_sbm.count}"
      end
    end
  end

  def answers_stats
    session_question = Assessment::RealtimeSessionQuestion.find(params[:session_question_id])
    question = session_question.question_assessment.question
    answers = question.answers.in_student_list(@realtime_session.student_seats.map{|s| s.std_course_id }).
        in_submission_list(@realtime_session.realtime_session_group.training.assessment.submissions.map{|s| s.id }).
        after_unlock_time(session_question.unlock_time)

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
