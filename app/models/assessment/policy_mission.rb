class Assessment::PolicyMission < ActiveRecord::Base
  acts_as_paranoid
  acts_as_duplicable
  is_a :assessment, as: :as_assessment, class_name: "Assessment"

	attr_accessible  :title, :description, :exp, :open_at, :close_at, :published, :comment_per_qn,
                   :dependent_id, :display_mode_id, :multiple_submissions, :reveal_answers, :hide_solution_from_wrong

  validates_presence_of :title, :exp, :open_at, :close_at

  before_destroy :clear_progression_policies_inheritance
	
  has_one :progression_policy, class_name: "Assessment::ProgressionPolicy"

  has_one :forward_policy, class_name: "Assessment::ForwardPolicy", through: :progression_policy,
          source: :as_progression_policy, source_type: "Assessment::ForwardPolicy"

  amoeba do
    #clone [:questions]
    include_field :progression_policy
    # as_requirements
  end

  def multipleAttempts?
    self.multiple_submissions
  end

  def revealAnswers? (curr_user_course)
    (curr_user_course.is_staff? or self.close_at < Time.now) and self.reveal_answers
  end
	
  def full_title
    "Regulated Trainings : #{self.title}"
  end

  def self.reflect_on_association(association)
    super || self.parent.reflect_on_association(association)
  end

  def as_lesson_plan_entry (course, user_course, manage_assessment)
    entry = LessonPlanEntry.create_virtual
    entry.title = self.title
    entry.description = self.description
    entry.entry_real_type = course.customized_title("Training")
    entry.start_at = self.open_at
    entry.end_at = self.close_at  if self.respond_to? :close_at
    entry.url = get_path
    entry.assessment = self
    entry.is_published = self.published
    entry.submission = user_course ?  get_modified_submission(course, user_course, manage_assessment) : nil
    entry.entry_type = 5

    lastSbm = self.submissions.where(std_course_id: user_course).last
    if self.multipleAttempts? and lastSbm and lastSbm.submitted? and can_access_with_end_check? user_course
      entry.entry_type = 6
      entry.submission[:actionSecondary] = "Reattempt"
      entry.submission[:urlSecondary] = reattempt_course_assessment_submissions_path(course, self.assessment, from_lesson_plan: true)
    end
    
    if !user_course.nil? and self.revealAnswers? (user_course)
      entry.entry_type = 6
      entry.submission[:actionTertiary] = "Answers"
      entry.submission[:urlTertiary] = answer_sheet_course_assessment_policy_mission_path(course, self)
    end
    entry
  end

  def get_modified_submission(course, user_course, manage_assessment)
    result = Hash.new
    completed_sub = self.submissions.submitted_format.where(std_course_id: user_course.id).first
    sub = self.submissions.where(std_course_id: user_course.id).order('updated_at DESC').first
    dependent_ast_sub = self.dependent_on.nil? ? nil : self.dependent_on.submissions.where(std_course_id: user_course.id).order('updated_at DESC').first
    
    if sub and sub.attempting? and can_access_with_end_check? user_course
      result[:action] = "Resume"
      result[:url] = edit_course_assessment_submission_path(course, self.assessment, sub, from_lesson_plan: true)
  	elsif sub and sub.submitted?
      result[:action] = "Review"  
      result[:url] = course_assessment_submission_path(course, self.assessment, sub, from_lesson_plan: true)
    elsif !(can_access_with_end_check? user_course ) and completed_sub
      result[:action] = "Review"  
      result[:url] = course_assessment_submission_path(course, self.assessment, completed_sub, from_lesson_plan: true)
    elsif ((self.opened? and (self.as_assessment.class == Assessment::Training or
        self.dependent_id.nil? or self.dependent_id == 0 or
        (!dependent_ast_sub.nil? and !dependent_ast_sub.attempting?))) or
        manage_assessment) and can_access_with_end_check? user_course
      result[:action] = "Attempt"
      result[:url] = new_course_assessment_submission_path(course, self.assessment, from_lesson_plan: true)
    else
      result[:action] = nil
    end
    result[:new] = false
    result[:opened] = self.opened?
    result[:published] = self.published
    result
  end

  def clear_progression_policies_inheritance
  	self.progression_policy.specific.destroy
  end
end
