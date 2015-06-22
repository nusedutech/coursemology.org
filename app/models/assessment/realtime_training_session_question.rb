class Assessment::RealtimeTrainingSessionQuestion < ActiveRecord::Base
  attr_accessible :question_assessment_id, :session_id, :unlock, :unlock_count

  belongs_to :session, class_name: Assessment::RealtimeTrainingSession, foreign_key: :session_id
  belongs_to :question_assessment, class_name: QuestionAssessment, foreign_key: :question_assessment_id
end
