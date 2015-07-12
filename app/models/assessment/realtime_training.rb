class Assessment::RealtimeTraining < ActiveRecord::Base
  acts_as_paranoid
  is_a :assessment, as: :as_assessment, class_name: "Assessment"

  attr_accessible :exp, :bonus_exp, :title, :description, :published, :comment_per_qn, :allow_discussion
  attr_accessible :open_at, :close_at, :bonus_cutoff_at, :tab_id, :display_mode_id, :dependent_id
  attr_accessible :average_grading, :seat_randomizable, :sessions_attributes

  validates_presence_of :title, :exp, :open_at

  has_many  :sessions, class_name: Assessment::RealtimeTrainingSession, dependent: :destroy

  accepts_nested_attributes_for :sessions, allow_destroy: true

  def full_title
    "#{I18n.t('Assessment.Realtime_Training')} : #{self.title}"
  end

  def self.reflect_on_association(association)
    super || self.parent.reflect_on_association(association)
  end

  def as_lesson_plan_entry (course, user_course, manage_assessment)
    entry = LessonPlanEntry.create_virtual
    entry.title = self.title
    entry.description = self.description
    entry.entry_type = 4
    entry.entry_real_type = course.customized_title("Training")
    entry.start_at = self.open_at
    entry.end_at = self.close_at  if self.respond_to? :close_at
    entry.url = get_path
    entry.assessment = self
    entry.is_published = self.published
    entry.submission = user_course ? get_submission(course, user_course, manage_assessment) : nil
    entry
  end
end
