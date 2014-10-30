class Assessment::PolicyMissionSubmissionsController < Assessment::SubmissionsController

	before_filter :authorize, only: [:new, :create, :update]
  before_filter :no_update_after_submission, only: [:edit, :update]

 	def show
		@policy_mission = @assessment.specific
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
					#Correct Answer - Move on!
					if response[:is_correct]
						forwardGroup.correct_amount_left = forwardGroup.correct_amount_left - 1
						if forwardGroup.correct_amount_left <= 0
							forwardGroup.is_completed = true
							forwardGroup.save

							#set next forward level
							nextForwardPolicyLevel = forwardPolicy.nextPolicyLevel forwardGroup.getCorrespondingLevel
							if nextForwardPolicyLevel != nil
								forwardGroup = Assessment::ForwardGroup.new
								forwardGroup.submission_id = @submission.id
								forwardGroup.forward_policy_level_id = nextForwardPolicyLevel.id
								forwardGroup.correct_amount_left = nextForwardPolicyLevel.progression_threshold
								forwardGroup.uncompleted_questions = nextForwardPolicyLevel.getAllQuestionsString @assessment
								forwardGroup.save
								@summary[:promoted] = true
							else
								forwardGroup = nil
							end
						else
							forwardGroup.save
						end
					end
					@summary[:lastResult] = response[:result]
					@summary[:explanation] = response[:explanation]
				end

			  if forwardGroup != nil
					forwardPolicyLevel = forwardGroup.getCorrespondingLevel
					tag = forwardPolicyLevel.getTag
					@summary[:tagName] = tag.name
				
					@summary[:completedQuestions] = forwardPolicyLevel.progression_threshold - forwardGroup.correct_amount_left
					@summary[:totalQuestions] = forwardPolicyLevel.progression_threshold
					current = forwardGroup.getTopQuestion @assessment
					@summary[:current] = current.specific
				else
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

  def authorize
    if curr_user_course.is_staff?
      return true
    end

    unless @assessment.can_start?(curr_user_course)
      redirect_to access_denied_course_assessment_path(@course, @assessment)
    end
  end

end
