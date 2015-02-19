class Assessment::PolicyMissionsController < Assessment::AssessmentsController
  require 'csv'
  load_and_authorize_resource :policy_mission, class: "Assessment::PolicyMission", through: :course
  before_filter :load_general_course_data, only: [:show, :index, :new, :edit, :access_denied, :stats, :overview, :listall, :answer_sheet]

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
	
  def edit
    @tags = @course.tags
    @topicconcepts = @course.topicconcepts.concepts
    @fwdPolicyLevels = @policy_mission.progression_policy.getForwardPolicy.getSortedPolicyLevels

    @forwardWrong = @policy_mission.progression_policy.getForwardPolicy.overall_wrong_threshold
  end

  def new
    @policy_missions = @course.policy_missions
    @policy_mission.exp = 200
    @policy_mission.open_at = DateTime.now.beginning_of_day
    @policy_mission.close_at = DateTime.now.end_of_day + 1  # 1 day from now
    @policy_mission.course_id = @course.id

    @tags = @course.tags
    @topicconcepts = @course.topicconcepts.concepts
    respond_to do |format|
      format.html
    end
  end

  def create
    @assessment = @policy_mission.assessment
    @policy_missions = @course.policy_missions
    @policy_mission.position = @course.policy_missions.count + 1
    @policy_mission.creator = current_user
    @policy_mission.course_id = @course.id

    forward_policy = Assessment::ForwardPolicy.new
    forward_policy.overall_wrong_threshold = 0

    invalidSaves = true
    invalidPublish = false
    respond_to do |format|
      if @policy_mission.save
        forward_policy.policy_mission_id = @policy_mission.id
        forward_policy.overall_wrong_threshold = params[:forward][:totalWrong]
        if forward_policy.save
          #Cannot publish if no policy levels exist
          invalidPublish = (params[:forward][:tag_id].size <= 0)
	  params[:forward][:tag_id].each_with_index do |tag_id, index|
            tagElement = getTagElement tag_id
            if tagElement.nil?
              invalidPublish = true
              break
            end

            forward_policy_level = Assessment::ForwardPolicyLevel.new
            forward_policy_level.tag = tagElement
            forward_policy_level.progression_threshold = params[:forward][:value][index]
            forward_policy_level.order = index
            forward_policy_level.forward_policy_id = forward_policy.id
            forward_policy_level.is_consecutive = (params[:forward][:movement][index] == "consecutive")
            forward_policy_level.save

            #Cannot publish as long as one single level is missing a question to do
            if forward_policy_level.getAllRelatedQuestions(@assessment).size  <= 0
              invalidPublish = true
            end
	  end
	  invalidSaves = false
        end
        @policy_mission.create_local_file
      end
      
      additionalPublishNotice = @policy_mission.assessment.published && invalidPublish ? " Cannot be published as missing forward levels with questions." : ""
      
      if @policy_mission.published
        @policy_mission.published = !invalidPublish
        @policy_mission.save
      end

      if invalidSaves
        format.html { render action: "new" }
      else
        format.html { redirect_to course_assessment_policy_mission_path(@course, @policy_mission),
                      notice: "The policy mission #{@policy_mission.title} has been created." + additionalPublishNotice}
      end
    end
  end

  def getTagElement tagString
    tagHash = JSON.parse tagString
    if tagHash.has_key?("Class") and tagHash.has_key?("Name") and tagHash["Class"] == "Tag"
      tagElements = @course.tags.where(name: tagHash["Name"])
      tagElements.size > 0 ? tagElements.first : nil
    elsif tagHash.has_key?("Class") and tagHash.has_key?("Name") and tagHash["Class"] == "Topicconcept"
      tagElements = @course.topicconcepts.where(name: tagHash["Name"])
      tagElements.size > 0 ? tagElements.first : nil
    else
      nil
    end 
  end

	def update
		@assessment = @policy_mission.assessment
    respond_to do |format|
      previouslyPublished = @policy_mission.published       
		  invalidPublish = false
      if @policy_mission.update_attributes(params[:assessment_policy_mission])
				if !previouslyPublished and @policy_mission.progression_policy.isForwardPolicy? and params.has_key?(:forward)
          #Remove all submissions - This is a reset to allow students to reattempt new forward policy format
          @assessment.submissions.destroy_all

					forward_policy = @policy_mission.progression_policy.getForwardPolicy
					forward_policy.overall_wrong_threshold = params[:forward][:totalWrong]
					forward_policy.deleteAllPolicyLevels
					forward_policy.save

          #Cannot publish if no policy levels exist
          invalidPublish = params[:forward][:tag_id].size <= 0
					params[:forward][:tag_id].each_with_index do |tag_id, index|
            tagElement = getTagElement tag_id
            if tagElement.nil?
              invalidPublish = true
              break
            end

						forward_policy_level = Assessment::ForwardPolicyLevel.new
						forward_policy_level.tag = tagElement
						forward_policy_level.progression_threshold = params[:forward][:value][index]
						forward_policy_level.order = index
						forward_policy_level.forward_policy_id = forward_policy.id
						forward_policy_level.is_consecutive = (params[:forward][:movement][index] == "consecutive")
						forward_policy_level.save

            #Cannot publish as long as one single level is missing a question to do
            if forward_policy_level.getAllRelatedQuestions(@assessment).size  <= 0
              invalidPublish = true
            end
					end
				end
				additionalPublishNotice = @policy_mission.published && invalidPublish ? "Cannot be published as missing forward levels with questions." : ""
				
				if @policy_mission.published
          @policy_mission.published = !invalidPublish
          @policy_mission.save
        end

        format.html { redirect_to course_assessment_policy_mission_path(@course, @policy_mission),
                                  notice: "The regulated training #{@policy_mission.title} has been updated." + additionalPublishNotice}
      else
        format.html {redirect_to edit_course_assessment_policy_mission_path(@course, @policy_mission) }
      end
    end
  end
	
	def update_questions
    if !params[:assessment].nil?
      ques_list = params[:assessment][:question_assessments]
    else
      ques_list = []
    end

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

    respond_to do |format|      
      if @policy_mission.update_attributes(params[:assessment_policy_mission])
        invalidPublish = false  
        forward_policy_levels = @policy_mission.progression_policy.getForwardPolicy.forward_policy_levels
        forward_policy_levels.each do |single_level|
          #Cannot publish as long as one single level is missing a question to do
          if single_level.getAllRelatedQuestions(@assessment).size  <= 0
            invalidPublish = true
            break
          end
        end
       
        additionalPublishNotice = @policy_mission.published && invalidPublish ? " Cannot be published as missing forward levels with questions." : ""
				
				if @policy_mission.published
          @policy_mission.published = !invalidPublish
          @policy_mission.save
        end

        format.html { redirect_to course_assessment_policy_mission_path(@course, @policy_mission),
                                  notice: "The regulated training #{@policy_mission.title} has been updated." + additionalPublishNotice}
      else
        format.html {redirect_to edit_course_assessment_policy_mission_path(@course, @policy_mission) }
      end
    end 
  end

  def destroy
    @policy_mission.destroy
    respond_to do |format|
      format.html { redirect_to course_assessment_trainings_url,
                                notice: "The regulated training #{@policy_mission.title} has been removed." }
    end
  end

  def answer_sheet
    if @policy_mission.revealAnswers? (curr_user_course)
      @pmAnswers = {}
      if @policy_mission.progression_policy.isForwardPolicy?
        forwardPolicy = @policy_mission.progression_policy.getForwardPolicy
        forwardPolicyLevels = forwardPolicy.forward_policy_levels
        @pmAnswers[:forwardContent] = {}
        @pmAnswers[:forwardContent][:tagGroup] = []
        forwardPolicyLevels.each do |singleLevel|
          packagedLevelQuestions = {}
          packagedLevelQuestions[:name] = singleLevel.getTag.name
          packagedLevelQuestions[:questions] = singleLevel.getAllRelatedQuestions @policy_mission.assessment
          @pmAnswers[:forwardContent][:tagGroup] << packagedLevelQuestions
        end
      end
      respond_to do |format|
        format.html
      end
    else
      respond_to do |format|
        format.html { 
          redirect_to access_denied_path, alert: "I see whatcha doing there..."
        }
      end   
      return 
    end
  end
end
