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
        redirect_to edit_course_assessment_submission_path(@course, @assessment, sbm)
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
		if @assessment.is_policy_mission? 
      if sbm && sbm.submitted?
        redirect_to edit_course_assessment_submission_path(@course, @assessment, sbm)
      end
      
			if @assessment.getPolicyMission.progression_policy.isForwardPolicy?
				forward_policy = @assessment.getPolicyMission.progression_policy.getForwardPolicy
				sortedPolicyLevels = forward_policy.getSortedPolicyLevels

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
					respond_to do |format|
		    		format.html { redirect_to edit_course_assessment_submission_path(@course, @assessment, @submission)}
		  		end
				else
					respond_to do |format|
					  format.html { redirect_to course_assessment_policy_mission_path(@course, @assessment),
													notice: "Invalid policy mission attempted" }
					end
				end
			end
    elsif @submission.save
      respond_to do |format|
        format.html { redirect_to edit_course_assessment_submission_path(@course, @assessment, @submission)}
      end
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
