class Assessment::RealtimeTrainingSeatAllocation < ActiveRecord::Base
  attr_accessible :seat_number, :session_id, :std_course_id, :table_number, :team_grade

  scope :belong_to_std, lambda { |std_user_couse| where(std_course_id: std_user_couse.id) }

  belongs_to :session, class_name: Assessment::RealtimeTrainingSession, foreign_key: :session_id
  belongs_to :student, class_name: UserCourse, foreign_key: :std_course_id
end
