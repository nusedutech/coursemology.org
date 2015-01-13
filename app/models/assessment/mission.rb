class Assessment::Mission < ActiveRecord::Base
  acts_as_paranoid
  is_a :assessment, as: :as_assessment, class_name: "Assessment"

  include Rails.application.routes.url_helpers

  attr_accessible :file_submission,
                  :file_submission_only

  attr_accessible  :title, :description, :exp, :open_at, :close_at, :published, :comment_per_qn,
                   :dependent_id, :display_mode_id,:allow_discussion

  validates_presence_of :title, :exp, :open_at, :close_at


  #TODO
  validates_with DateValidator, fields: [:open_at, :close_at]

  def full_title
    "#{I18n.t('Assessment.Mission')} : #{self.title}"
  end

  def total_exp
    exp
  end

  def get_path
    course_assessment_mission_path(self.course, self)
  end

  def single_question?
    questions.count == 1
  end

  def missions_dep_on_published
    missions_dependent_on.where(publish:true)
  end

  def current_exp
    exp
  end

  #TODO: refactor
  def self.reflect_on_association(association)
    super || self.parent.reflect_on_association(association)
  end

  def as_lesson_plan_entry (course, user_course)
    entry = LessonPlanEntry.create_virtual
    entry.title = self.title
    entry.description = self.description
    entry.entry_type = 4
    entry.entry_real_type = course.customized_title("Mission")
    entry.start_at = self.open_at
    entry.end_at = self.close_at  if self.respond_to? :close_at
    entry.url = get_path
    entry.assessment = self
    entry.is_published = self.published
    entry.submission = user_course ? get_submission(course, user_course) : nil
    entry
  end

end
