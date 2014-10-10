class Assessment::PolicyMissionsController < Assessment::AssessmentsController
	load_and_authorize_resource :policy_mission, class: "Assessment::PolicyMission", through: :course

	def show
    @assessment = @policy_mission.assessment
    if curr_user_course.is_student? and !@assessment.can_start?(curr_user_course)
      redirect_to course_assessment_policy_missions_path
      return
    end
    super
    @summary[:allowed_questions] = [Assessment::McqQuestion]
    @summary[:type] = 'policy_mission'
    @summary[:specific] = @policy_mission

    respond_to do |format|
      format.html { render "assessment/assessments/show" }
    end
  end
	
	def new
		@policy_missions = @course.missions
    @policy_mission.exp = 200
    @policy_mission.open_at = DateTime.now.beginning_of_day
    @policy_mission.close_at = DateTime.now.end_of_day + 1  # 1 day from now
    @policy_mission.course_id = @course.id
		respond_to do |format|
			format.html
		end
	end

	def create
    @policy_missions = @course.missions
    @policy_mission.position = @course.missions.count + 1
    @policy_mission.creator = current_user
    @policy_mission.course_id = @course.id

    respond_to do |format|
      if @policy_mission.save
        @policy_mission.create_local_file
        format.html { redirect_to course_assessment_policy_mission_path(@course, @policy_mission),
                                  notice: "The policy mission #{@policy_mission.title} has been created." }
      else
        format.html { render action: "new" }
      end
    end
  end

	def update
    respond_to do |format|
      if !params[:assessment].nil? 
        update_questions params[:assessment][:question_assessments]
      else
        update_questions []
      end      
      if @policy_mission.update_attributes(params[:assessment_policy_mission])
        format.html { redirect_to course_assessment_policy_mission_path(@course, @policy_mission),
                                  notice: "The policy mission #{@policy_mission.title} has been updated."}
      else
        format.html {redirect_to edit_course_assessment_policy_mission_path(@course, @policy_mission) }
      end
    end
  end
	
	def update_questions ques_list
    if (!ques_list.nil?)
      old_list = @policy_mission.as_assessment.question_assessments
      ques_list.each do |q|
        if old_list.where(:question_id => q).count === 0
          qa = QuestionAssessment.new 
          qa.question_id = q
          qa.assessment_id =  @policy_mission.assessment.id
          qa.position = @policy_mission.questions.count
          qa.save
        end
      end
      old_list.each do |qa|
        if !ques_list.include? qa.question.id.to_s
          qa.destroy
        end
      end
    end      
  end

end
