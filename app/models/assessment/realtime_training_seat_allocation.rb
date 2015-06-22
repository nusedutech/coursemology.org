class Assessment::RealtimeTrainingSeatAllocation < ActiveRecord::Base
  attr_accessible :seat_number, :session_id, :std_course_id

  belongs_to :session, class_name: Assessment::RealtimeTrainingSession, foreign_key: :session_id
  belongs_to :student, class_name: UserCourse, foreign_key: :std_course_id
end
