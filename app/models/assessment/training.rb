class Assessment::Training < ActiveRecord::Base
  acts_as_paranoid
  is_a :assessment, as: :as_assessment, class_name: "Assessment"

  #TODO, fix
  attr_accessible :exp, :bonus_exp
  attr_accessible :title, :description
  attr_accessible :published, :comment_per_qn
  attr_accessible :open_at, :close_at, :bonus_cutoff_at
  attr_accessible :tab_id, :display_mode_id, :dependent_id
  attr_accessible :allow_discussion

  attr_accessible :skippable, :test, :duration, :option_grading, :show_solution_after_close, :always_full_exp

  validates_presence_of :title, :exp, :open_at

  validates_with DateValidator, fields: [:open_at, :bonus_cutoff_at]

  scope :not_test, -> { where("test is null or test = 0") }
  scope :without_session_group, lambda { |course| where("assessment_trainings.id not in (?)",
         course.realtime_session_groups.where("training_id is not null").select(:training_id).uniq.map(&:training_id).push(0))}


  has_many :realtime_session_groups, class_name: Assessment::RealtimeSessionGroup, foreign_key: :training_id
  has_many :sessions, through: :realtime_session_groups

  def full_title
    "#{I18n.t('Assessment.Training')} : #{self.title}"
  end

  def self.reflect_on_association(association)
    super || self.parent.reflect_on_association(association)
  end
  #
  # def self.reflect_on_aggregation(name)
  #   super || self.parent.reflect_on_aggregation(name)
  # end
  #
  # def column_for_attribute(name)
  #   super || self.assessment.column_for_attribute(name)
  # end

  def get_path
    course_assessment_training_path(self.course, self)
  end

  def as_lesson_plan_entry (course, user_course, manage_assessment)
    entry = LessonPlanEntry.create_virtual
    entry.title = self.title
    entry.description = self.description
    entry.entry_type = 5
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
