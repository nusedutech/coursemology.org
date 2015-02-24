class Assessment::SubmissionsController < ApplicationController
  load_and_authorize_resource :course
  load_and_authorize_resource :assessment, through: :course, class: "Assessment"
  load_and_authorize_resource :submission, through: :assessment, class: "Assessment::Submission", id_param: "id", except: :new
  before_filter :load_general_course_data, only: [:show, :new, :create, :edit]

  before_filter :build_resource, only: :new

  def new
    sbm = @assessment.submissions.where(std_course_id: curr_user_course).last
    if curr_user_course.is_student? && sbm.nil?
      Activity.attempted_asm(curr_user_course, @assessment)
    end

    if sbm
      @submission = sbm
    else
      @submission.std_course = curr_user_course
    end

    if @assessment.is_a?(Assessment::Training)
      @reattempt = @course.training_reattempt
      #continue unfinished training, or go to finished training of can't reattempt
      if sbm && (!sbm.graded? ||  !@reattempt || !@reattempt.display)
        redirect_to_edit params
        return
      end
      sbm_count = @assessment.submissions.where(std_course_id: curr_user_course).count
      if sbm_count > 0
        @submission.multiplier = @reattempt.prefer_value.to_f / 100
      end
      @submission.save
      @submission.gradings.create({grade: 0, std_course_id: curr_user_course.id})
    end

		#Processing permutation for policy levels
		if @assessment.is_policy_mission? && sbm && sbm.submitted?
      respond_to do |format|
        format.html { redirect_to course_assessment_submission_path(@course, @assessment, sbm)}
      end
    elsif @assessment.is_policy_mission? && sbm && sbm.attempting?
      respond_to do |format|
        format.html { redirect_to edit_course_assessment_submission_path(@course, @assessment, sbm)}
      end
    elsif @assessment.is_policy_mission?
      new_policy_mission
      return
    elsif @submission.save
      session[:attempt_flag] = true
      redirect_to_edit params
    end
  end

  def new_policy_mission
    policy_mission = @assessment.specific
		if policy_mission.progression_policy.isForwardPolicy?
			forward_policy = @assessment.getPolicyMission.progression_policy.getForwardPolicy
			sortedPolicyLevels = forward_policy.getSortedPolicyLevels
      
      #Error check for missing questions placed at certain levels
      sortedPolicyLevels.each do |singleLevel|
        if singleLevel.getAllRelatedQuestions(@assessment).size  <= 0
          redirect_for_invalid_policy_mission "Certain levels do not have questions added yet."
          return
        end
      end

			#Process only valid policy missions
			if sortedPolicyLevels.size > 0 && @submission.save
				forward_group = Assessment::ForwardGroup.new
				forward_group.submission_id = @submission.id
				forward_group.forward_policy_level_id = sortedPolicyLevels[0].id
				forward_group.correct_amount_left = sortedPolicyLevels[0].progression_threshold
				forward_group.uncompleted_questions = sortedPolicyLevels[0].getAllQuestionsString @assessment
				forward_group.is_consecutive = sortedPolicyLevels[0].is_consecutive
				#If not set (forward_policy.overall_wrong_threshold == 0), set to -1 to avoid confusion in decrement later
				forward_group.wrong_qn_left = forward_policy.overall_wrong_threshold == 0 ? -1 : forward_policy.overall_wrong_threshold
				forward_group.save

        redirect_to_edit params
			else
			  redirect_for_invalid_policy_mission "Invalid policy mission attempted"
			end
		end
  end

  def redirect_to_edit params
    caller_flag = params[:from_lesson_plan]
    respond_to do |format|
      if caller_flag.nil?
        format.html { redirect_to edit_course_assessment_submission_path(@course, @assessment, @submission)}
      else
        format.html { redirect_to edit_course_assessment_submission_path(@course, @assessment, @submission, :from_lesson_plan => true, :discuss => params['discuss'])}
      end
    end
  end

  def redirect_for_invalid_policy_mission (message)
    policy_mission = @assessment.specific
    respond_to do |format|
		  format.html { redirect_to course_assessment_policy_mission_path(@course, policy_mission),
										notice: message }
		end
  end

  def render_lesson_plan_view (course, assessment, params, mission_show, user_course)
    respond_to do |format|
      @from_lesson_plan = params[:from_lesson_plan]
      @current_id = assessment.nil? ? '0' : "virtual-entity-#{assessment.id}"
      @discuss = params[:discuss]
      @mission_show = mission_show
      @milestones = LessonPlanEntry.get_milestones_for_course(course, current_ability, (can? :manage, Assessment::Mission), user_course, can?(:manage, Assessment))
       format.html { render "lesson_plan/submission" }
    end
  end

  private

  def build_resource
    #Additional numeric check to prevent collection methods from defaulting to member methods
    if params[:id] and params[:id].is_a? Numeric
      @submission = @assessment.submissions.send(:find, params[:id])
    elsif params[:action] == 'index'
      @submissions = @assessment.submissions.accessible_by(current_ability)
    else
      @submission = @assessment.submissions.new
    end
  end


end
