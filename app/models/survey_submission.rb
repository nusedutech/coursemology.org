class SurveySubmission < ActiveRecord::Base
  acts_as_paranoid
  attr_accessible :user_course_id, :survey_id, :open_at, :submitted_at, :status, :current_qn

  belongs_to :user_course
  belongs_to :survey, class_name: "Survey"
  has_many   :survey_mrq_answers, dependent: :destroy
  has_many   :survey_essay_answers, dependent: :destroy
  belongs_to :exp_transaction

  default_scope includes(:user_course)

  scope :exclude_phantom, where("user_courses.is_phantom = 0")
  scope :students, -> { where("user_courses.role_id = ?", Role.find_by_name('student').id) }


  def set_started
    self.status = 'started'
    self.save
  end

  def get_answer(qn)
    if qn.is_essay?
      survey_essay_answers.where(question_id: qn)
    else
      survey_mrq_answers.where(question_id: qn)
    end
  end

  def set_submitted
    unless submitted?
      pending_action = user_course.pending_actions.where(item_type: Survey.to_s, item_id: self.survey.id).first
      pending_action.set_done if pending_action
    end
    if !submitted? and (survey.anonymous or survey.exp.to_i >= 0)
      self.exp_transaction = ExpTransaction.new
      self.exp_transaction.user_course = self.user_course
      self.exp_transaction.reason = "Exp for #{survey.title}"
      self.exp_transaction.is_valid = true
      self.exp_transaction.exp = survey.exp ? survey.exp : 0
      self.exp_transaction.rewardable = survey
      self.save
      self.exp_transaction.update_user_data
    end

    self.status = 'submitted'
    self.submitted_at = Time.now
    self.save
    self.make_anonymmous if survey.anonymous and self.user_course.is_real_student?
  end

  def started?
    self.status == 'started'
  end

  def submitted?
    self.status == 'submitted'
  end

  def done?
    (self.current_qn || 1) > self.survey.survey_questions.count
  end

  def make_anonymmous
    (survey_mrq_answers.to_a + survey_essay_answers.to_a).each do |ans|
      ans.update_attribute(:user_course_id,nil)
    end
    self.update_attribute(:user_course_id,nil)
  end
end
