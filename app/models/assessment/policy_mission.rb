class Assessment::PolicyMission < ActiveRecord::Base
  acts_as_paranoid
  is_a :assessment, as: :as_assessment, class_name: "Assessment"

	attr_accessible  :title, :description, :exp, :open_at, :close_at, :published, :comment_per_qn,
                   :dependent_id, :display_mode_id, :multiple_submissions, :reveal_answers

  validates_presence_of :title, :exp, :open_at, :close_at
	
	has_one :progression_policy, class_name: "Assessment::ProgressionPolicy",  dependent: :destroy

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
    entry.submission = user_course ? get_submission(course, user_course, manage_assessment) : nil
    entry.entry_type = 4

    lastSbm = self.submissions.where(std_course_id: user_course).last
    if self.multipleAttempts? and lastSbm and lastSbm.submitted?
      entry.entry_type = 5
      entry.submission[:actionSecondary] = "Reattempt"
      entry.submission[:urlSecondary] = reattempt_course_assessment_submissions_path(course, self.assessment, from_lesson_plan: true)
    end
    
    if !user_course.nil? and self.revealAnswers? (user_course)
      entry.entry_type = 5
      entry.submission[:actionTertiary] = "Answers"
      entry.submission[:urlTertiary] = answer_sheet_course_assessment_policy_mission_path(course, self)
    end
    entry
  end

end
