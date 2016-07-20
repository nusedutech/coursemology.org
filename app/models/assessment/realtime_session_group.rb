class Assessment::RealtimeSessionGroup < ActiveRecord::Base
  acts_as_paranoid
  is_a :assessment, as: :as_assessment, class_name: "Assessment"

  attr_accessible :average_grading, :mission_id, :seat_randomizable, :title, :training_id
  attr_accessible :exp, :bonus_exp, :description, :published, :recitation, :open_at, :close_at,:sessions_attributes

  validates_presence_of :title, :open_at

  has_many  :sessions, class_name: Assessment::RealtimeSession, foreign_key: :session_group_id, dependent: :destroy
  belongs_to :training, class_name: Assessment::Training, foreign_key: :training_id
  belongs_to :mission, class_name: Assessment::Mission, foreign_key: :mission_id

  before_save :sync_recitation_session, if: :recitation?

  accepts_nested_attributes_for :sessions, allow_destroy: true

  def full_title
    "#{I18n.t('Assessment.RealtimeSession')} : #{self.title}"
  end

  def self.reflect_on_association(association)
    super || self.parent.reflect_on_association(association)
  end

  def as_lesson_plan_entry (course, user_course, manage_assessment)
    entry = LessonPlanEntry.create_virtual
    entry.title = self.title
    entry.description = self.description
    entry.entry_type = 5
    entry.entry_real_type = course.customized_title("Realtime_Session")
    entry.start_at = self.open_at
    entry.end_at = self.close_at  if self.respond_to? :close_at
    entry.url = get_path
    entry.assessment = self
    entry.is_published = self.published
    entry.submission = {action: "Real-Time Session List", url: course_assessment_realtime_session_groups_path(course)}
    entry
  end

  def update_session_questions(old_training, old_mission)
    if self.training != old_training
      self.sessions.each do |s|
        s.session_questions.relate_to_assessment(old_training.assessment.id).destroy_all if old_training
        if self.training
          self.training.question_assessments.each do |qa|
            s.session_questions.create(question_assessment_id: qa.id, unlock: false, unlock_count: 0)
          end
        end
      end
    end
    if self.mission != old_mission
      self.sessions.each do |s|
        s.session_questions.relate_to_assessment(old_mission.assessment.id).destroy_all if old_mission
        if self.mission
          self.mission.question_assessments.each do |qa|
            s.session_questions.create(question_assessment_id: qa.id, unlock: true, unlock_count: 0)
          end
        end
      end
    end
  end

  private

  def sync_recitation_session
    build_recitation_session if new_record?

    session = sessions.first
    session.update_attributes(start_time: open_at, end_time: close_at)
  end

  def build_recitation_session
    sessions.clear

    sessions.build(start_time: open_at, end_time: close_at)
  end
end
