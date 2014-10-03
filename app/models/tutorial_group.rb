class TutorialGroup < ActiveRecord::Base
  attr_accessible :course_id, :std_course_id, :tut_course_id

  belongs_to :course
  belongs_to :std_course, class_name: "UserCourse"
  belongs_to :tut_course, class_name: "UserCourse"
  belongs_to :group, class_name: "StudentGroup"

  validates :std_course_id, presence: true
  validates :tut_course_id, presence: true

  before_destroy :unsubscribe_comments
  before_create :subscribe_comments

  after_save :after_save
  after_destroy :after_destroy

  default_scope includes(:std_course, :tut_course)

  def unsubscribe_comments
    # TODO: update subscription
    # unsubscribe everything related to this student
    std_course.comment_topics.each do |topic|
      CommentSubscription.unsubscribe(topic, tut_course)
    end
  end

  def subscribe_comments
    # TODO: update subscription
    std_course.comment_topics.each do |topic|
      CommentSubscription.subscribe(topic, tut_course)
    end
  end

  def after_save
    Rails.cache.delete("my_tutor_#{self.std_course_id}")

  end

  def after_destroy
    Rails.cache.delete("my_tutor_#{self.std_course_id}")
  end

  def self.check (file, course)
    csv_text = File.read(file.path)
    csv = CSV.parse(csv_text, :headers => true)

    obj_list = []
    csv.each_with_index do |row, index|
      error = ""
      if row["id"].nil?
        error = error + "id is empty,"
      elsif course.users.where(:name => row["id"]).first.nil?
        error = error + "id does not exist,"
      elsif row["group"].nil?
        error = error + "group is empty,"
      end
      obj_list << {:id => row["id"], :name => row["name"], :email => row["email"], :group => row["group"], :status => (error!="" ? error : "accepted")}

    end

    return obj_list
  end

  def self.import (students, current_user, course)
    students["status"].each_with_index do |s, index|
      if s == "accepted"
        std_course = course.user_courses.where(:course_id => course.id, :user_id => course.users.where(:name => students["id"][index]).first.id).first
        ctg = course.tutorial_groups.where(:std_course_id => std_course.id).first
        if ctg.nil?
          tg = TutorialGroup.new
          tg.course = course
          tg.std_course = std_course
          sg = StudentGroup.where(:name => students["group"][index]).first
          if sg.nil?
            sg = StudentGroup.new(:name => students["group"][index])
            sg.course = course
            sg.save
          end

          tg.group = sg
          tg.save
        else
          sg = StudentGroup.where(:name => students["group"][index]).first
          if sg.nil?
            sg = StudentGroup.new(:name => students["group"][index])
            sg.course = course
            sg.save
          end
          ctg.group = sg
          ctg.save
        end
      end
    end
  end
end
