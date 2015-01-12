class StatsController < ApplicationController
  load_and_authorize_resource :course
  before_filter :load_general_course_data

  def general
    authorize! :manage, @course
  end

  # data is a map of the chart column to list of student submission
  def produce_submission_graph(data, key_label, graph_title)
    grade_table = GoogleVisualr::DataTable.new
    grade_table.new_column('string', key_label)
    grade_table.new_column('number', 'Count')
    grade_table.new_column('string', nil, nil, 'tooltip')
    data.sort.each do |k, sbms|
      row = []
      row << k.to_s
      row << sbms.size
      tooltip = sbms.map { |sbm| sbm.std_course.name }.join(", ")
      row << tooltip
      grade_table.add_row(row)
    end
    opts   = { width: 600, height: 240, title: graph_title, hAxis: { title: key_label } }
    GoogleVisualr::Interactive::ColumnChart.new(grade_table, opts)
  end

  def mission
    @mission = Assessment::Mission.find(params[:mission_id])
    authorize! :manage, @mission

    @sbms = @mission.submissions
    @graded = @sbms.where(status: 'graded').map { |sbm| sbm.std_course }
    @submitted = @sbms.where(status: 'submitted').map { |sbm| sbm.std_course }
    @attempting = @sbms.where(status: 'attempting').map { |sbm| sbm.std_course }

    # TODO: split submitted to doing vs submitted
    # when saving mission is allowed

    all_std = @course.student_courses
    @unsubmitted = all_std -  @attempting -  @submitted - @graded

    sbms_graded = @sbms.graded
    sbms_by_grade = sbms_graded.group_by { |sbm| sbm.get_final_grading.grade }
    @grade_chart = produce_submission_graph(sbms_by_grade, 'Grade', 'Grade distribution')

    sbms_by_date = sbms_graded.group_by { |sbm| sbm.created_at.to_date.to_s }
    @date_chart = produce_submission_graph(sbms_by_date, 'Date', 'Start date distribution')

    @missions = @course.missions
    @trainings = @course.trainings
		@policy_missions = @course.policy_missions
  end

  def training
    @training = Assessment::Training.find(params[:training_id])
    authorize! :manage, @training

    @summary = {}
    is_all = ((params[:mode] != nil) && params[:mode] == "all") || (curr_user_course.std_courses.count == 0)
    puts is_all

    #TODO: may want to deal with phantom students here
    @summary[:all] = is_all
    std_courses = is_all ? @course.student_courses : curr_user_course.std_courses
    @summary[:student_courses] = std_courses

    submissions =  @training.submissions.where(std_course_id: std_courses)
    submitted = submissions.map { |sbm| sbm.std_course }

    @not_started = std_courses - submitted
    @summary[:not_started] = @not_started

    sbms_by_grade = submissions.group_by { |sbm| sbm.get_final_grading.grade }
    @summary[:grade_chart] = produce_submission_graph(sbms_by_grade, 'Grade', 'Grade distribution')

    sbms_by_date = submissions.group_by { |sbm| sbm.created_at.strftime("%m-%d") }
    @summary[:date_chart] = produce_submission_graph(sbms_by_date, 'Date', 'Start date distribution')

    @summary[:progress] = submissions.group_by{ |sbm| sbm.assessment.questions.finalised(sbm).count + 1 }

    @summary[:progress_chart] = produce_submission_graph(@summary[:progress], 'Step', 'Current step of students')

    #@mcqs = @training.mcqs
    #@coding_question = @training.coding_questions

    @missions = @course.missions
    @trainings = @course.trainings
		@policy_missions = @course.policy_missions
  end

	def policy_mission
		@policy_mission = Assessment::PolicyMission.find(params[:policy_mission_id])
    authorize! :manage, @policy_mission

		@summary = {}
		if @policy_mission.progression_policy.isForwardPolicy?
			forwardPolicy = @policy_mission.progression_policy.getForwardPolicy
			forwardPolicyLevels = forwardPolicy.forward_policy_levels
			@summary[:forwardContent] = {}
			@summary[:forwardContent][:tagGroup] = []
			forwardPolicyLevels.each do |singleLevel|
				packagedLevelQuestions = {}
				packagedLevelQuestions[:name] = singleLevel.getTag.name
				packagedLevelQuestions[:questions] = singleLevel.getAllRelatedQuestions @policy_mission.assessment
				@summary[:forwardContent][:tagGroup] << packagedLevelQuestions
			end
		end

		@missions = @course.missions
    @trainings = @course.trainings
		@policy_missions = @course.policy_missions
	end

	#Extract all policy mission statistics via excel
	def policy_mission_export_excel
		@policy_mission = Assessment::PolicyMission.find(params[:policy_mission_id])
    authorize! :manage, @policy_mission

		@summary = {}
		#Extract all of the students data
		#student_courses = @course.user_courses.student.order('lower(name)')

		if @policy_mission.progression_policy.isForwardPolicy?
			
			forwardPolicy = @policy_mission.progression_policy.getForwardPolicy
			forwardPolicyLevels = forwardPolicy.forward_policy_levels
			@summary[:forwardContent] = {}
			@summary[:forwardContent][:tagGroup] = []
			forwardPolicyLevels.each do |singleLevel|
				packagedLevelQuestions = {}
				packagedLevelQuestions[:name] = singleLevel.getTag.name
				packagedLevelQuestions[:questions] = singleLevel.getAllRelatedQuestions @policy_mission.assessment
				@summary[:forwardContent][:tagGroup] << packagedLevelQuestions
			end

			#Overall statistics for each student
			@summary[:forwardContent][:studentSubmissions] = []

			#Record each submission separately
			@policy_mission.submissions.each do |singleSubmission|

				student = singleSubmission.std_course.user
				packageSubmissionUser = {}
				packageSubmissionUser[:id] = student.id
				packageSubmissionUser[:name] = student.name
				packageSubmissionUser[:status] = "Pass" #default pass - we check for failing condition and overwrite
				packageSubmissionUser[:highestLevel] = "All mastered" #default all mastered - check for lower mastery and overwrite
        packageSubmissionUser[:masteryString] = ""
				packageSubmissionUser[:levelInfos] = []
				previousTiming = singleSubmission.created_at

				allProgressionGroups = singleSubmission.progression_groups.where("is_completed = 1")
				#Separate each entries by the progression levels
				allProgressionGroups.each do |progressionGroup|
					forwardGroup = progressionGroup.getForwardGroup
					tagName = progressionGroup.getTagName	
					allMcqAnswers = forwardGroup.getAllAnswers
					numCorrect = 0
					numTotal = 0

					#Counting right answers
					allMcqAnswers.each do |singleAnsweredQn|
						packageSubmissionUser[:masteryString] = packageSubmissionUser[:masteryString] + tagName
            mcqQuestion = singleAnsweredQn.question.specific
            
						if singleAnsweredQn.correct
							numCorrect += 1
              packageSubmissionUser[:masteryString] = packageSubmissionUser[:masteryString] + "," + "1"
            else
              packageSubmissionUser[:masteryString] = packageSubmissionUser[:masteryString] + "," + "0"
						end
						numTotal += 1
						
						#Calculate timing to answer question from previous timing
						timingQn = (singleAnsweredQn.created_at - previousTiming)
					  #Update timing for next question
						previousTiming = singleAnsweredQn.created_at
						packageSubmissionUser[:masteryString] = packageSubmissionUser[:masteryString] + "," + mcqQuestion.id.to_s + "," + timingQn.to_s + ";"
					end

					#Validate student's mastery level
          if progressionGroup.correct_amount_left > 0
            packageSubmissionUser[:status] = "Fail"
          	packageSubmissionUser[:highestLevel] = tagName
          end

					packageSubmissionUser[:levelInfos] << numCorrect.to_s + " / " + numTotal.to_s
				end
				@summary[:forwardContent][:studentSubmissions] << packageSubmissionUser
			end
		end

		respond_to do |format|
			headers["Content-Disposition"] = "attachment; filename=\"Assignment #{@policy_mission.title}\""
			headers["Content-Type"] = "xls"
			format.xls
		end
	end
end
