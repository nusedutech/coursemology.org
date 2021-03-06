class Assessment::RealtimeSession < ActiveRecord::Base
  acts_as_paranoid
  attr_accessible :end_time, :number_of_table, :seat_per_table, :start_time, :status, :student_group_id, :student_group

  scope :include_std, lambda { |std_user_couse| joins(:student_seats).
      where("assessment_realtime_seat_allocations.std_course_id=?", std_user_couse.id) }
  scope :started, -> { where(status: true) }

  belongs_to :realtime_session_group, class_name: Assessment::RealtimeSessionGroup, foreign_key: :session_group_id
  belongs_to :student_group
  delegate :tutor, :to => :student_group

  has_many :students, through: :student_group

  has_many :student_seats, class_name: Assessment::RealtimeSeatAllocation, foreign_key: :session_id, dependent: :destroy
  has_many :session_questions, class_name: Assessment::RealtimeSessionQuestion, foreign_key: :session_id, dependent: :destroy
  has_many :question_assessments, through: :session_questions, source: :question_assessment
  has_many :questions, through: :question_assessments

  def allocate_seats
    return if recitation_group?

    if(self.students.count <= self.number_of_table*self.seat_per_table)
      seat_list = (1..self.students.count).to_a.shuffle
      self.students.each_with_index do |s,i|
        self.student_seats.create(std_course_id: s.id,
                                  table_number: (seat_list[i]%self.seat_per_table==0 ? seat_list[i]/self.seat_per_table : seat_list[i]/self.seat_per_table + 1),
                                  seat_number: (seat_list[i]%self.seat_per_table==0 ? self.seat_per_table : seat_list[i]%self.seat_per_table))
      end
    end
  end

  def get_student_seats_by_seat(table, seat)
    self.student_seats.where(table_number: table, seat_number: seat)
  end

  def get_student_seats_by_table(table)
    self.student_seats.where(table_number: table)
  end

  def close_session
    self.update_attribute(:status, false)
  end

  def reset
    self.session_questions.each do |sq|
      sq.lock
    end
  end

  def students
    if recitation_group?
      realtime_session_group.course.user_courses.real_students
    else
      super
    end
  end

  def student_ids
    recitation_group? ? students.map(&:id) : student_seats.map(&:std_course_id)
  end

  def recitation_group?
    realtime_session_group && realtime_session_group.recitation?
  end
end
