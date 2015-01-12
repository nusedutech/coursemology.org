class Assessment::PolicyMissionSubmissionsController < Assessment::SubmissionsController

	before_filter :authorize, only: [:new, :create, :update, :show, :show_export_excel, :reattempt]
  before_filter :no_showing_before_submission, only: [:show, :show_export_excel]
  before_filter :no_update_after_submission, only: [:edit, :update]

 	def show
		@policy_mission = @assessment.specific
		@summary = {}
   
    if @policy_mission.multipleAttempts?
      #Get all attempts for displaying later
      @allSubmissions = @assessment.submissions.where(std_course_id: @submission.std_course)
    end

		if @policy_mission.progression_policy.isForwardPolicy?
			forwardPolicy = @policy_mission.progression_policy.getForwardPolicy
			allProgressionGroups = @submission.progression_groups.where("is_completed = 1")

			@summary[:forwardContent] = {}
			@summary[:forwardContent][:status] = true
			@summary[:forwardContent][:highestLevel] = "Invalid"
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

				allMcqAnswers = forwardGroup.getAllAnswers
				questions = []
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
      if @submission.save
        respond_to do |format|
        		format.html { redirect_to new_course_assessment_submission_path(@course, @assessment)}
        end
      end
    else
		  respond_to do |format|
					format.html { redirect_to course_assessment_policy_mission_path(@course, @policy_mission),
												notice: "Invalid policy mission attempted" }
			end
    end
  end

  def edit
		@policy_mission = @assessment.specific
		if @policy_mission.progression_policy.isForwardPolicy?
			forwardPolicy = @policy_mission.progression_policy.getForwardPolicy
			psuedo_groups = @submission.progression_groups.where("is_completed = 0")
			#Getting progress attributes and next question id
			if psuedo_groups.size == 1
				forwardGroup = psuedo_groups[0].getForwardGroup

				@summary = {}
				current = forwardGroup.getTopQuestion @assessment
				if (params.has_key?(:qid) && params[:qid].to_i == current.id)
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
				end

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
					#@submission.update_grade
				end				
				respond_to do |format|
					format.html 
				end
			else
				respond_to do |format|
					format.html { redirect_to course_assessment_policy_mission_path(@course, @policy_mission) }
				end
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

	def no_update_after_submission
    unless @submission.attempting?
      respond_to do |format|
        format.html { redirect_to course_assessment_submission_path(@course, @assessment, @submission),
                                  notice: "Your have already submitted this mission." }
      end
    end
  end

  def no_showing_before_submission
    unless !@submission.attempting?
      respond_to do |format|
        format.html { redirect_to edit_course_assessment_submission_path(@course, @assessment, @submission),
                                  notice: "Your have not finished this mission." }
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

end
