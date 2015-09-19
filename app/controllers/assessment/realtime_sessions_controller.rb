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
    training = @realtime_session.realtime_session_group.training
    sbms = training.submissions.belong_to_stds(@realtime_session.student_seats.map{|s| s.std_course_id })
    sbms.each do |sbm|
      sbm.update_grade
    end

    (1..@realtime_session.number_of_table).each_with_index do |t,i|
      session_students = @realtime_session.get_student_seats_by_table(t).has_student
      if session_students.count > 0
        sm_list = {}
        session_students.map {|ss| ss.team_grade=0 }

        #update team grade separately
        training.questions.each do |q|
          sum_on_q = 0
          std_answered = []
          session_students.each do |ss|
            sbm = !ss.student.nil? ? ss.student.submissions.where(assessment_id: training.assessment.id).last : nil
            ans = sbm ? sbm.answers.select{|an| an.question==q and an.answer_grading }.last : nil
            if ans
              sm_list[ss.id] = sbm if sbm and sm_list[ss.id].nil?
              std_answered << ss
              sum_on_q += ans.answer_grading.grade if ans.answer_grading and ans.answer_grading.grade
            end
          end
          session_students.each do |ss|
            ss.team_grade += (sum_on_q/std_answered.count) if std_answered.include?(ss)
            ss.save
          end
        end

        #add exp
        session_students.each do |ss|
          if !sm_list[ss.id].nil?
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
            grading.exp_transaction.exp = asm.max_grade.nil? ? 0 : ((ss.team_grade*25/100 + (grading.grade.nil? ? 0 : grading.grade)*75/100) || 0) * asm.exp / asm.max_grade
            grading.exp_transaction.save
          end
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

    @realtime_session.close_session
    @realtime_session.reset
    flash[:notice] = "Grade finalization is done!"
    redirect_to :back
  end

  def finalize_grade_mission
    #TODO: REFACRORING - update grade for all student on table
    #set submitted to all submission first
    sbms = @realtime_session.realtime_session_group.mission.submissions.belong_to_stds(@realtime_session.student_seats.map{|s| s.std_course_id })
    sbms.each do |sbm|
      sbm.set_submitted
    end

    #Build the team submission of mission
    (1..@realtime_session.number_of_table).each_with_index do |t,i|
      session_students = @realtime_session.get_student_seats_by_table(t).has_student
      if session_students.count > 0
        sm_list = {}
        no_sm_count = 0

        #build team submission
        session_students.each do |ss|
          ss.team_submission.destroy if ss.team_submission
          ss.team_submission_id = nil
          ss.save
          sm = !ss.student.nil? ? ss.student.submissions.where(assessment_id: @realtime_session.realtime_session_group.mission.assessment.id).last : nil
          sm_list[ss.id] = sm if !sm.nil?
        end
        if sm_list.count > 0
          team_sbm = @realtime_session.realtime_session_group.mission.submissions.create
          team_sbm.set_generated
          team_sbm.build_initial_answers_for_team sm_list

          session_students.each do |ss|
            ss.team_submission_id = team_sbm.id if !sm_list[ss.id].nil?
            ss.save
          end
        end
      end

    end

    @realtime_session.close_session
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
          session_question.session.reset
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

  def close_session
    @realtime_session.close_session
    @realtime_session.reset
    redirect_to course_assessment_realtime_session_groups_path
  end
end
