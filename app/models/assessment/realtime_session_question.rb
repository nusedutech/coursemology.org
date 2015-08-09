class Assessment::RealtimeSessionQuestion < ActiveRecord::Base
  attr_accessible :question_assessment_id, :session_id, :unlock, :unlock_count, :updated_at

  scope :relate_to_question, lambda { |q_a| where(question_assessment_id: q_a.id) }
  scope :relate_to_assessment, lambda { |assessment_id| joins("INNER JOIN question_assessments ON assessment_realtime_session_questions.question_assessment_id = question_assessments.id")
                                              .where("question_assessments.assessment_id = ?",assessment_id) }
  belongs_to :session, class_name: Assessment::RealtimeSession, foreign_key: :session_id
  belongs_to :question_assessment, class_name: QuestionAssessment, foreign_key: :question_assessment_id

  def lock
    self.update_attribute(:unlock, false)
  end
end
