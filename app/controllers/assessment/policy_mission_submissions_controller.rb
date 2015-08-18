class Assessment::PolicyMissionSubmissionsController < Assessment::SubmissionsController

  before_filter :authorize, only: [:new, :create, :update, :show, :show_export_excel, :reattempt, :edit, :destroy]
  before_filter :authorize_for_end, only: [:new, :create, :update, :reattempt, :edit, :destroy]

  before_filter :no_showing_before_submission, only: [:show, :show_export_excel]
  before_filter :no_update_after_submission, only: [:edit, :update]

  def show
    @policy_mission = @assessment.specific
    @summary = {}
   
    if @policy_mission.multipleAttempts?
      #Get all attempts for displaying later
      @allSubmissions = @assessment.submissions.where(std_course_id: @submission.std_course, status: :submitted)
    end

    if @policy_mission.progression_policy.isForwardPolicy?
      forwardPolicy = @policy_mission.progression_policy.getForwardPolicy
      allProgressionGroups = @submission.progression_groups.where("is_completed = 1")

      @summary[:forwardContent] = {}
      @summary[:forwardContent][:status] = true
      @summary[:forwardContent][:highestLevel] = "None"
      @summary[:forwardContent][:wrongCount] = 0
      forwardLevelsContent = []	
      allProgressionGroups.each do |progressionGroup|

        forwardGroup = progressionGroup.getForwardGroup
        forwardPolicyLevel = forwardGroup.getCorrespondingLevel
        tag = forwardPolicyLevel.getTag

        #Uncompleted Progression - Mission failed
        if progressionGroup.correct_amount_left > 0
          @summary[:forwardContent][:status] = false
        else
          @summary[:forwardContent][:highestLevel] = tag.name
        end

        questions = []
        allMcqAnswers = forwardGroup.getAllAnswers
        allMcqAnswers.each do |singleAnsweredQn|
          mcqQuestion = singleAnsweredQn.question.specific
  	      questionSummary = {}
          questionSummary[:correct] = singleAnsweredQn.correct
	        questionSummary[:description] = mcqQuestion.description
	        questionSummary[:rightOption] = mcqQuestion.getCorrectOptions 

	        #For incorrectly answered questions only
	       if !singleAnsweredQn.correct
	         @summary[:forwardContent][:wrongCount] += 1
	         questionSummary[:chosenOption] = []						
	         singleAnsweredQn.answer_options.each do |answerToOptionMapping|
             questionSummary[:chosenOption] << answerToOptionMapping.option
	         end
	       end

	      questions << questionSummary
        end
		
        summarizedContent = {}
        summarizedContent[:tagName] = tag.name
        summarizedContent[:questions] = questions

        forwardLevelsContent << summarizedContent
      end

      @summary[:forwardContent][:levels] = forwardLevelsContent
    end

    #Policy Mission in lesson plan - Show view
    if !params[:from_lesson_plan].nil? && params[:from_lesson_plan] == "true"
      render_lesson_plan_view(@course, @assessment, params, true, @curr_user_course)
    end
  end

  def show_export_excel
    self.show
    respond_to do |format|
      headers["Content-Disposition"] = "attachment; filename=\"Student-#{current_user.name}-#{@policy_mission.title}\""
      headers["Content-Type"] = "xls"
      format.xls
    end
  end

  def reattempt
    @policy_mission = @assessment.specific
    lastSbm = @assessment.submissions.where(std_course_id: curr_user_course).last
    if @policy_mission.multipleAttempts? and lastSbm and lastSbm.submitted?
      @submission = @assessment.submissions.new
      @submission.std_course = curr_user_course
      @submission.save
      new_policy_mission
    elsif lastSbm and lastSbm.attempting?
      respond_to do |format|
        format.html { redirect_to edit_course_assessment_submission_path(@course, @assessment, lastSbm),
                      notice: "Your have not finished this mission." }
      end
    else
      respond_to do |format|
        format.html { redirect_to course_assessment_policy_mission_path(@course, @policy_mission),
                      notice: "Invalid regulated training attempted" }
      end
    end
  end

  def edit
    @policy_mission = @assessment.specific
    if @policy_mission.progression_policy.isForwardPolicy?
      edit_for_forward_policy
      return
    else
      redirect_for_invalid_policy_mission "Invalid mission progression type."
    end
  end

  def edit_for_forward_policy
    forwardPolicy = @policy_mission.progression_policy.getForwardPolicy
    psuedo_groups = @submission.progression_groups.where("is_completed = 0")

    #Revised error recovery protocol, remove excess groups and redirect use to do
    #assessment
    if psuedo_groups.size > 1
      psuedo_groups.each_with_index do |group, index|
        if index != 0 
          group.getForwardGroup.destroy 
        end
      end
      psuedo_groups = @submission.progression_groups.where("is_completed = 0")
    end

    #Getting progress attributes and next question id
    if psuedo_groups.size == 1
      forwardGroup = psuedo_groups[0].getForwardGroup

      @summary = {}
      current = forwardGroup.getTopQuestion @assessment
      #Forward group might not been initialised due to a bug, reinitialise it
      #This also helps with resetting unintentional changes when questions are removed
      if current.nil?
        sortedPolicyLevels = forwardPolicy.getSortedPolicyLevels
        forwardGroup.forward_policy_level_id = sortedPolicyLevels[0].id
        forwardGroup.correct_amount_left = sortedPolicyLevels[0].progression_threshold
        forwardGroup.uncompleted_questions = sortedPolicyLevels[0].getAllQuestionsString @assessment
	      forwardGroup.is_consecutive = sortedPolicyLevels[0].is_consecutive
      	forwardGroup.wrong_qn_left = forwardPolicy.overall_wrong_threshold == 0 ? -1 : forwardPolicy.overall_wrong_threshold
	      forwardGroup.save
	      current = forwardGroup.getTopQuestion @assessment
      end
      if !current.nil? && (params.has_key?(:qid) && params[:qid].to_i == current.id) && params.has_key?(:answers)
        question = @assessment.questions.find_by_id(params[:qid]).specific
        response = submit_mcq(question)
        forwardGroup.removeTopQuestion
        forwardGroup.recordAnswer(response[:answer_id])
        forwardGroup.save
        #Correct Answer - Move on!
        if response[:is_correct]
          forwardGroup.correct_amount_left = forwardGroup.correct_amount_left - 1
          if forwardGroup.correct_amount_left <= 0
            forwardGroup.is_completed = true
            forwardGroup.save
            wrongQnLeft = forwardGroup.wrong_qn_left 
            #set next forward level
            nextForwardPolicyLevel = forwardPolicy.nextPolicyLevel forwardGroup.getCorrespondingLevel
            if nextForwardPolicyLevel != nil
              forwardGroup = Assessment::ForwardGroup.new
              forwardGroup.submission_id = @submission.id
              forwardGroup.forward_policy_level_id = nextForwardPolicyLevel.id
              forwardGroup.correct_amount_left = nextForwardPolicyLevel.progression_threshold
              forwardGroup.uncompleted_questions = nextForwardPolicyLevel.getAllQuestionsString @assessment
              forwardGroup.is_consecutive = nextForwardPolicyLevel.is_consecutive
              forwardGroup.wrong_qn_left = wrongQnLeft
              forwardGroup.save
              @summary[:promoted] = true
            else
              forwardGroup = nil
            end
          else
            forwardGroup.save
          end
	      #If consecutive and wrong question, reset progress
        elsif forwardGroup.is_consecutive
	        forwardPolicyLevel = forwardGroup.getCorrespondingLevel
	        forwardGroup.correct_amount_left = forwardPolicyLevel.progression_threshold
	        @summary[:reset] = true
	        forwardGroup.wrong_qn_left -= 1
	        forwardGroup.save
	      #If just wrong question
        else
	        forwardGroup.wrong_qn_left -= 1
        	forwardGroup.save
        end
        @summary[:lastResult] = response[:result]
        @summary[:explanation] = response[:explanation]
      elsif current.nil?
        redirect_for_invalid_policy_mission "Current level does not contain any questions."
        return
      end

      @summary[:forwardGroup] = forwardGroup
      if forwardGroup != nil && forwardGroup.wrong_qn_left != 0
        forwardPolicyLevel = forwardGroup.getCorrespondingLevel
        tag = forwardPolicyLevel.getTag
        @summary[:tagName] = tag.name
        @summary[:consecutive] = forwardGroup.is_consecutive
        @summary[:completedQuestions] = forwardPolicyLevel.progression_threshold - forwardGroup.correct_amount_left
        @summary[:totalQuestions] = forwardPolicyLevel.progression_threshold
        current = forwardGroup.getTopQuestion @assessment
        @summary[:current] = current.specific
      else
        if forwardGroup != nil
          forwardGroup.is_completed = true
          forwardGroup.save
        end
        @submission.set_submitted
        grading = @submission.get_final_grading
        grading.update_exp_transaction if forwardGroup == nil
        #@submission.update_grade
      end

      #Mission in lesson plan - Edit view
      if params.has_key?(:from_lesson_plan) && params[:from_lesson_plan] == "true"
        render_lesson_plan_view(@course, @assessment, params, nil, @curr_user_course)
      end
    #Invalid situation where no completed and uncompleted progression groups - invoke creator again
    elsif psuedo_groups.size == 0 && @submission.progression_groups.where("is_completed = 1").size == 0
      new_policy_mission
    #No size means all are done - Can also occur when code above invoke a new instantiation
    #to level up, but a separate 
    elsif psuedo_groups.size == 0
      respond_to do |format|
        format.html {
	        redirect_to course_assessment_policy_mission_path(@course, @policy_mission),
	        notice: "Zero Entry Error."
	      }
      end
    #More than one cleanup
    else
      respond_to do |format|
      format.html { redirect_to course_assessment_policy_mission_path(@course, @policy_mission, :from_lesson_plan => params['from_lesson_plan'], :discuss => params['discuss']) }
      end
    end
  end

  def submit_mcq(question)
    if params[:answers].is_a?(Array)
      selected_options = question.options.find_all_by_id(params[:answers])
    else
      selected_options = question.options.find_all_by_id([params[:answers]])
    end
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

    if correct && !@submission.graded?
      grade = AutoGrader.mcq_grader(@submission, ans.answer, question, pref_grader)
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

    {is_correct: correct,
     result: correct ? correct_str : "Incorrect!",
     explanation: explanation,
		 answer_id: ans.id
    }
  end

  def progression_group_cleanup
    @submission.progression_groups.where("is_completed = 0").destroy_all
  end

  def no_update_after_submission
    unless @submission.attempting?
      respond_to do |format|
        format.html { redirect_to course_assessment_submission_path(@course, @assessment, @submission, :from_lesson_plan => params['from_lesson_plan'], :discuss => params['discuss']),
                                  notice: "Your have already submitted this mission." }
      end
    end
  end

  def no_showing_before_submission
    unless !@submission.attempting?
      respond_to do |format|
        format.html { redirect_to edit_course_assessment_submission_path(@course, @assessment, @submission), notice: "Your have not finished this mission." }
      end
    end
  end


  def authorize
    if curr_user_course.is_staff?
      return true
    end

    unless @assessment.can_start?(curr_user_course)
      redirect_to access_denied_course_assessment_path(@course, @assessment)
    end
  end

  def authorize_for_end
    if curr_user_course.is_staff?
      return true
    end


    if @assessment.has_ended?
      redirect_to access_denied_course_assessment_path(@course, @assessment)
    end
  end

  def destroy
    if can? :manage, Assessment::PolicyMission
		  @policy_mission = @assessment.specific
		  @submission.destroy
		  respond_to do |format|
		    format.html { redirect_to submissions_course_assessment_policy_missions_path(@course),
		                  notice: "Submission by " + @submission.std_course.name + " has been deleted."}
		  end
    end
  end
end
