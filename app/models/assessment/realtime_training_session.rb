class Assessment::RealtimeTrainingSession < ActiveRecord::Base
  attr_accessible :end_time, :number_of_table, :seat_per_table, :start_time, :status, :student_group_id, :student_group

  belongs_to :realtime_training, class_name: Assessment::RealtimeTraining, foreign_key: :realtime_training_id, dependent: :destroy
  belongs_to :student_group, dependent: :destroy

  has_many :student_seats, class_name: Assessment::RealtimeTrainingSeatAllocation, as: :session
  has_many :session_questions, class_name: Assessment::RealtimeTrainingSessionQuestion, foreign_key: :session_id, dependent: :destroy
  has_many :question_assessments, through: :session_questions, source: :question_assessment
  has_many :questions, through: :question_assessments
end
