class Assessment::RealtimeTrainingSubmissionsController < Assessment::SubmissionsController

  skip_load_and_authorize_resource :realtime_training_submission
  skip_load_and_authorize_resource :realtime_training, only: :listall

  before_filter :authorize, only: [:new, :edit]
  before_filter :load_general_course_data, only: [:show, :edit]


  def show
    @realtime_training = @assessment.specific
    @grading = @submission.get_final_grading
  end

  def edit
    #1. half way, redirect to next undone question, or finalised one if requested, or requested one if stuff or skippable
    #2. finished, list all submissions

    #implementation, build step control UI separately
    # @next_undone

    @realtime_training = @assessment.specific

    #check student's realtime training session started
    session = @realtime_training.sessions.include_std(curr_user_course).started.first
    if curr_user_course.is_student? and !session
      redirect_to     else
      questions = @assessment.questions
      finalised = @assessment.questions.finalised_for_test(@submission)
      current =  (questions - finalised).first
      next_undone = (questions.index(current) || questions.length) + 1

      request_step = (params[:step] || next_undone).to_i
      step = request_step #curr_user_course.is_staff? ? request_step : [next_undone , request_step].min
      step = step > questions.length ? next_undone : step
      current = step > questions.length ? current : questions[step - 1]

        current = current.specific if current
      if current && current.class == Assessment::CodingQuestion
        prefilled_code = current.template
        if current.dependent_on
          std_answer = current.dependent_on.answers.where("correct = 1 AND std_course_id = ?", curr_user_course.id).last
          code = std_answer ? std_answer.content : ""
          prefilled_code = "#Answer from your previous question \n" + code + (prefilled_code.empty? ? "" : ("\n\n#prefilled code \n" + prefilled_code))
        end
      end

      #check current (current question) is unclocked
      session_question = current.nil? ? nil : session.session_questions.relate_to_question(@assessment.question_assessments.where(question_id: current.question.id).first).first
      @summary = {session: session, session_question: session_question, questions: questions, finalised: finalised, step: step,
                  current: (!@submission.graded? ? current : nil), next_undone: next_undone, prefilled: prefilled_code, remain_time: ( defined? remain_time ? remain_time : 0)}

      #Training in lesson plan
      if !params[:from_lesson_plan].nil? && params[:from_lesson_plan] == "true"
        render_lesson_plan_view(@course, @assessment, params, nil, @curr_user_course)
      end

    end
  end

  def check_question_unlocked
    if params[:session_question_id]
      respond_to do |format|
        if Assessment::RealtimeTrainingSessionQuestion.find(params[:session_question_id]).unlock
          format.json { render json: { result: true}}
        else
          format.json { render json: { result: false}}
        end
      end
    end
  end

  def submit
    if params[:sq_id] and params[:sid]
      question = @assessment.questions.find_by_id(params[:qid]).specific
      answers = question.answers.where(submission_id: params[:sid], std_course_id: curr_user_course.id)
      session_question = Assessment::RealtimeTrainingSessionQuestion.find(params[:sq_id])
      session_question.update_attribute(:unlock_count, answers.count + 1) if session_question.unlock_count > answers.count + 1
      response = {}
      if !session_question.unlock
        response = {
            result: false,
            explanation: "This question has been locked."
        }
      elsif answers.count >= session_question.unlock_count
        response = {
            result: false,
            explanation: "You answered this question already."
        }
      else
        case
          when question.class == Assessment::McqQuestion
            response = submit_mcq(question)
          when question.class == Assessment::CodingQuestion
            response = submit_code(question)
          else
            #nothing yet
        end
      end
    end
    respond_to do |format|
      format.json {render json: response}
    end
  end

  def submit_mcq(question)
    session_question = Assessment::RealtimeTrainingSessionQuestion.find(params[:sq_id])
    selected_options = question.options.find_all_by_id(params[:aid])
    eval_array = selected_options.map(&:correct)
    incomplete = false
    correct = eval_array.reduce {|x, y| x && y}

    if correct && question.select_all?
      correct = selected_options.length == question.options.where(correct: true).count
      incomplete = !correct
    end

    ans = Assessment::McqAnswer.create({std_course_id: curr_user_course.id,
                                        question_id: question.question.id,
                                        submission_id: @submission.id,
                                        correct: correct,
                                        finalised: correct
                                       })
    ans.answer_options.create(selected_options.map {|so| {option_id: so.id}})

    grade  = 0
    pref_grader = @course.mcq_auto_grader.prefer_value


    if !@submission.graded?
      grade = AutoGrader.mcq_grader(@submission, ans.answer, question, pref_grader)
      if @submission.done?
        @submission.update_grade

      end
    end

    if pref_grader == 'two-one-zero'
      grade_str = grade > 0 ? " + #{grade}" : ""
      correct_str =  "Correct! #{grade_str}"
    else
      correct_str =  "Correct!"
    end

    if question.select_all?
      if incomplete
        explanation = "Not all correct answers are selected."
      else
        c_count = eval_array.select{|x| x}.length
        explanation = "#{c_count} correct, #{eval_array.length - c_count} wrong"
      end
    else
      explanation = selected_options.first.explanation
    end

    {
     result: true,
     is_correct: true,
     explanation: "Your answer is submited."
    }
  end


  def submit_code(question)
    require_dependency 'auto_grader'

    code = params[:code]
    sma = Assessment::CodingAnswer.create({ std_course_id: curr_user_course.id,
                                            question_id: question.question.id,
                                            submission_id: @submission.id,
                                            content: code}).answer

    #evaluate
    code_to_write = PythonEvaluator.combine_code([question.pre_include, code, question.append_code])
    eval_summary = PythonEvaluator.eval_python(PythonEvaluator.get_asm_file_path(@assessment), code_to_write, question)
    public_tests = eval_summary[:public].length == 0 ? true : eval_summary[:public].inject{|sum,a| sum and a}
    private_tests = eval_summary[:private].length == 0 ? true : eval_summary[:private].inject{|sum,a| sum and a}

    #if fail private test cases, show hints
    if public_tests and eval_summary[:private].length > 0 and !private_tests
      index = eval_summary[:private].find_index(false)
      eval_summary[:hint] = question.data_hash["private"][index]["hint"]
    end

    if eval_summary[:errors].length == 0 and public_tests and private_tests
      sma.correct = true
      sma.finalised = true
      sma.save
    end

    if sma.correct && !@submission.graded?
      AutoGrader.coding_question_grader(@submission, question, sma)
      # only update grade after finishing the assignments
      if @submission.done?
        @submission.update_grade
      end
    end
    eval_summary
  end

  def destroy
    @submission.destroy
    respond_to do |format|
      format.html { redirect_to submissions_course_assessment_realtime_trainings_path(@course),
                                notice: "Submission by " + @submission.std_course.name + " has been deleted."}
    end
  end

  private
  def authorize
    if curr_user_course.is_staff?
      return true
    end

    unless @assessment.can_start?(curr_user_course)
      redirect_to access_denied_course_assessment_path(@course, @assessment)
    end
  end
end
