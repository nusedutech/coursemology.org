class StudentGroup < ActiveRecord::Base
  acts_as_paranoid
  attr_accessible :course_id, :name

  belongs_to :course
  has_many :tutorial_groups, class_name: "TutorialGroup", foreign_key: "group_id", dependent: :destroy

end
