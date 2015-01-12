class LessonPlanMilestone < ActiveRecord::Base
  attr_accessible :title, :description, :end_at, :start_at, :is_publish

  belongs_to :course
  belongs_to :creator, class_name: "User"

  validates :start_at, presence: true, allow_blank: false

  # Creates a virtual item of this class that is backed by some other data store.
  def self.create_virtual(*args)
    (Class.new do
        def initialize(title, other_entries)
          @title = title
          @previous_milestone = nil
          @next_milestone = nil
          @other_entries = other_entries
        end

        def title
          @title
        end
        def description
          nil
        end
        def entries (include_virtual = true, user_course = nil)
          @other_entries
        end
        def start_at
          nil
        end
        def end_at
          nil
        end
        def previous_milestone
          @previous_milestone
        end
        def previous_milestone=(milestone)
          @previous_milestone = milestone
        end
        def next_milestone
          @next_milestone
        end
        def next_milestone=(milestone)
          @next_milestone = milestone
        end
        def is_virtual?
          true
        end
    end).new(*args)
  end
  
  def previous_milestone
    self.course.lesson_plan_milestones.where("start_at < :start_at", :start_at => self.start_at).order("start_at DESC").first
  end

  def next_milestone
    self.course.lesson_plan_milestones.where("start_at > :start_at", :start_at => self.start_at).order("start_at ASC").first
  end

  def entries(include_virtual = true, user_course = nil)
    next_milestone = self.next_milestone
    cutoff_time = if self.end_at then self.end_at.end_of_day end
    start_date = self.start_at

    if next_milestone and not next_milestone.is_virtual?
      if not self.end_at or next_milestone.start_at - self.end_at > 86400
        cutoff_time = next_milestone.start_at
      end
    end

    start_after_us = "start_at >= :start_at"
    before_cutoff = if cutoff_time then " AND start_at < :cutoff" else "" end
    in_current_course = " AND course_id = :course_id"

    actual_entries = LessonPlanEntry.where(start_after_us + before_cutoff + in_current_course,
      :start_at => start_date, :cutoff => cutoff_time, :course_id => self.course_id)

    #check for tutorial group, load for specific student lesson plan
    if user_course.is_student?
      student_tutorial_groups = user_course.tut_group_courses.order(:created_at).to_a
      current_tutorial = user_course.tut_group_courses.where(:milestone_id => self.id).first

      str_query = ''
      if current_tutorial
        str_query = " or (entry_type = 2 and group_id is not null and group_id = #{current_tutorial.group_id})"
      end
      actual_entries = actual_entries.where("entry_type <> 2 or (entry_type = 2 and group_id is null)" + str_query)
    end

    if include_virtual
      virtual_entries = course.lesson_plan_virtual_entries(start_date, cutoff_time, user_course)
      virtual_strictly_before_cutoff = virtual_entries.select do |e|
        if cutoff_time
          e.start_at < cutoff_time
        end
      end
      actual_entries + virtual_strictly_before_cutoff
    else
      actual_entries
    end
  end

  def is_virtual?
    false
  end
end
