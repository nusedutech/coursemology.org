class Assessment::MissionSubmissionsController < Assessment::SubmissionsController
  before_filter :authorize, only: [:new, :create, :edit, :update]
  before_filter :no_update_after_submission, only: [:edit, :update]

  def show
    # if student is still attempting a mission, redirect to edit page
    if @submission.attempting? and @submission.std_course == curr_user_course
      redirect_to edit_course_assessment_submission_path(@course, @assessment, @submission)
      return
    end

    #if staff is accessing the submitted mission, redirect to grading page
    if curr_user_course.is_staff? and (@submission.submitted? or @submission.graded?)
        redirect_to new_course_assessment_submission_grading_path(@course, @assessment, @submission)
      return
    end

    if @submission.graded?
      grading = @submission.gradings.first
      redirect_to course_assessment_submission_grading_path(@course, @assessment, @submission,grading)
    end

    #Mission in lesson plan - Show view
    if !params[:from_lesson_plan].nil? && params[:from_lesson_plan] == "true"
      render_lesson_plan_view(@course, @assessment, params, true, @curr_user_course)
    end
  end


  def create
    update
  end

  def edit
    @mission = @assessment.as_assessment
    @questions = @assessment.questions
    @submission.build_initial_answers

    #process for realtime session training
    if @mission.realtime_session_groups.count > 0 and @mission.sessions.include_std(curr_user_course).started.first
      @questions = []
      @assessment.questions.each do |qu|
        if qu.is_a? Assessment::MpqQuestion
          @questions << qu
          qu.sub_questions.each do |s_qu|
            @questions << s_qu
          end
        else
          @questions << qu
        end
      end
      #check student's realtime training session started
      session = @mission.sessions.include_std(curr_user_course).started.first
      finalised = []#@assessment.questions.finalised_for_test(@submission)
      current =  (@questions - finalised).first
      next_undone = (@questions.index(current) || @questions.length) + 1

      request_step = (params[:step] || next_undone).to_i
      step = request_step #curr_user_course.is_staff? ? request_step : [next_undone , request_step].min
      step = step > @questions.length ? @questions.length+1 : step # next_undone : step
      current = step > @questions.length ? current : @questions[step - 1]

      current = current.specific if current

      #check current (current question) is unclocked
      student_seat = session.student_seats.where(std_course_id: curr_user_course.id).first
      #get all teammate
      table_answers = []
      teammate_seats = session.student_seats.where(table_number: student_seat.table_number)
      teammate_answers = @assessment.answers.where("assessment_answers.question_id = (?) and assessment_answers.std_course_id in (?)",current.question.id,teammate_seats.map {|ts| ts.std_course_id})

      if !current.nil? and current.parent
        session_question = session.session_questions.relate_to_question(@assessment.question_assessments.where(question_id: current.parent.question.id).first).first
      else
        session_question = current.nil? ? nil : session.session_questions.relate_to_question(@assessment.question_assessments.where(question_id: current.question.id).first).first
      end

      @summary = {session: session, session_question: session_question, student_seat: student_seat, questions: @questions, finalised: finalised, step: step,
                  current: (!@submission.submitted? ? current : nil), next_undone: next_undone, teammate_answers: teammate_answers}

    end

    #Mission in lesson plan - Edit view
    if !params[:from_lesson_plan].nil? && params[:from_lesson_plan] == "true"
      render_lesson_plan_view(@course, @assessment, params, nil, @curr_user_course)
    end
  end

  def update
    @mission = @assessment.as_assessment
    session = @assessment.sessions.find(params[:session_id]) if !params[:session_id].nil?
    s_q = session ? session.session_questions.find(params[:session_question_id]) : nil
    q = s_q.question_assessment.question.sub_questions.find(params[:question_id]) if s_q and s_q.question_assessment.question.is_a? Assessment::MpqQuestion
    if @assessment.realtime_session_groups.count > 0 and session and session.status and s_q and
        (!s_q.unlock or (s_q.unlock and q and q.id != s_q.unlock_count ))
      respond_to do |format|
      @submission.set_attempting
      format.html { redirect_to edit_course_assessment_submission_path(@course, @assessment, @submission,step: params[:step],result: 'locked', anchor: 'training-stop-pos'),
                                error: "This question is locked." }
      end
    else
      @submission.fetch_params_answers(params)
      if params[:files]
        @submission.attach_files(params[:files].values)
      end

      #set voted answer for realtime mission submission
      votes = params[:votes] || []
      votes.each do |qid, q_id|
        ans = @submission.answers.find_by_question_id(qid)
        ans.as_answer.voted_answer_id = q_id
        ans.as_answer.save
      end

      respond_to do |format|
        if @submission.save
          if params[:commit] == 'Save'
            @submission.set_attempting
            format.html { redirect_to edit_course_assessment_submission_path(@course, @assessment, @submission),
                                      notice: "Your submission has been saved." }
          elsif params[:commit] == 'Submit Answer'
            @submission.set_attempting
            format.html { redirect_to edit_course_assessment_submission_path(@course, @assessment, @submission,step: params[:step],result: true, anchor: 'training-stop-pos'),
                                      notice: "Your answer has been saved." }
          else
            @submission.set_submitted
            format.html { redirect_to course_assessment_submission_path(@course, @assessment, @submission),
                                      notice: "Your submission has been updated." }
          end
        else
          format.html { render action: "edit" }
        end
      end
    end

  end

  def unsubmit
    @submission.set_attempting
    flash[:notice] = "Successfully unsubmited submission."
    redirect_to course_assessment_submission_path(@course, @assessment, @submission)
  end

  def test_answer
    code = params[:code]
    std_answer = @submission.answers.where(id: params[:answer_id]).first
    if std_answer.attempt_left <= 0 and !curr_user_course.is_staff?
      result = {access_error: true, msg: "exceeds maximum testing times"}
    else
      std_answer.attempt_left -= 1
      std_answer.content = code
      std_answer.save
      qn = std_answer.question
      combined_code = PythonEvaluator.combine_code([qn.pre_include, std_answer.content, qn.append_code])
      result = PythonEvaluator.eval_python(PythonEvaluator.get_asm_file_path(@assessment), combined_code, qn.specific, false)
    end
    result[:can_test] = std_answer.can_run_test? curr_user_course
    respond_to do |format|
      format.html {render json: result}
    end
  end

  private

  def allow_only_one_submission
    sub = @mission.submissions.where(std_course_id:curr_user_course.id).first
    if sub
      @submission = sub
    else
      @submission.std_course = curr_user_course
    end
    @submission.attempt_mission
  end

  def no_update_after_submission
    unless @submission.attempting?
     respond_to do |format|
        format.html { redirect_to course_assessment_submission_path(@course, @assessment, @submission, :from_lesson_plan => params['from_lesson_plan'], :discuss => params['discuss']),
                                notice: "Your have already submitted this mission." }
     end
    end
  end

  def authorize
    if curr_user_course.is_staff?
      return true
    end

    can_start = @assessment.can_start?(curr_user_course)
    unless can_start
      redirect_to course_mission_access_denied_path(@course, @mission)
    end
  end

end
