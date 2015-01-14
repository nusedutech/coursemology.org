class LessonPlanEntry < ActiveRecord::Base
  attr_accessible :title, :entry_type, :description, :start_at, :end_at, :location, :resources

  validates_with DateValidator, fields: [:start_at, :end_at]

  belongs_to :course
  belongs_to :creator, class_name: "User"
  belongs_to :group, class_name: "StudentGroup"
  has_many :resources, class_name: "LessonPlanResource"

  has_many :taggable_tags, as: :taggable, dependent: :destroy
  has_many :topicconcepts, through: :taggable_tags, source: :tag, source_type: "Topicconcept"


  after_save :save_resources
  
  def save_resources
    if self.resources then
      self.resources.each { |r|
        r.save
      }
    end
  end

  # Creates a virtual item of this class that is backed by some other data store.
  def self.create_virtual
    (Class.new do
      def initialize
        @title = @description = @real_type = @start_at = @end_at = nil
        @resources = []
        @submission = Hash.new
      end

      def title
        @title
      end
      def title=(title)
        @title = title
      end
      def entry_type
        @type
      end
      def entry_type=(type)
        @type = type
      end
      def entry_real_type
        @real_type
      end
      def entry_real_type=(type)
        @real_type = type
      end
      def description
        @description
      end
      def description=(description)
        @description = description
      end
      def start_at
        @start_at
      end
      def start_at=(start_at)
        @start_at = start_at
      end
      def end_at
        @end_at
      end
      def end_at=(end_at)
        @end_at = end_at
      end
      def resources
        @resources
      end
      def resources=(resources)
        @resources = resources
      end
      def location
        nil
      end

      # Extra property that real entries do not have, so we can jump to them.
      def assessment
        @assessment
      end
      def assessment=(assessment)
        @assessment = assessment
      end

      def url
        @url
      end
      def url=(url)
        @url = url
      end
      
      def is_virtual?
        true
      end
      
      def is_published
        @is_published
      end
      
      def is_published=(is_published)
        @is_published = is_published
      end

      def submission
        @submission
      end
      def submission=(submission)
        @submission = submission
      end
    end).new
  end

  # Defines all the types
  ENTRY_TYPES = [
    ['Lecture', 0],
    ['Recitation', 1],
    ['Tutorial', 2],
    ['Video', 3],
    ['Other', 4]
  ]

  def entry_real_type
    LessonPlanEntry::ENTRY_TYPES[self.entry_type][0]
  end
  
  def is_virtual?
    false
  end
  def is_published
    true
  end

  def self.get_milestones_for_course(course, current_ability, can_manage_mission, curr_user_course, manage_assessment)
    milestones = course.lesson_plan_milestones.accessible_by(current_ability).order("start_at")


    other_entries_milestone = create_other_items_milestone(milestones, course, can_manage_mission, curr_user_course, manage_assessment)
    prior_entries_milestone = create_prior_items_milestone(milestones, course, can_manage_mission, curr_user_course, manage_assessment)

    milestones <<= other_entries_milestone
    if prior_entries_milestone
      milestones.insert(0, prior_entries_milestone)
    end

    milestones
  end

  def self.entries_between_date_range(start_date, end_date, course, can_manage_mission, curr_user_course, manage_assessment)
    if can_manage_mission
      virtual_entries = course.lesson_plan_virtual_entries(start_date, end_date, curr_user_course, manage_assessment)
    else
      virtual_entries = course.lesson_plan_virtual_entries(start_date, end_date, curr_user_course, manage_assessment).select { |entry| entry.is_published }
    end

    after_start = if start_date then "AND start_at > :start_date " else "" end
    before_end = if end_date then "AND end_at < :end_date" else "" end

    actual_entries = course.lesson_plan_entries.where("TRUE " + after_start + before_end,
                                                       :start_date => start_date, :end_date => end_date)

    entries_in_range = virtual_entries + actual_entries
    entries_in_range.sort_by { |e| e.start_at }
  end

  def self.create_other_items_milestone(all_milestones, course, can_manage_mission, curr_user_course, manage_assessment)
    last_milestone = if all_milestones.length > 0 then
                       all_milestones[all_milestones.length - 1]
                     else
                       nil
                     end

    other_entries = if last_milestone and last_milestone.end_at then
                      entries_between_date_range(last_milestone.end_at.advance(:days =>1), nil, course, can_manage_mission, curr_user_course, manage_assessment)
                    elsif last_milestone
                      []
                    else
                      entries_between_date_range(nil, nil, course, can_manage_mission, curr_user_course, manage_assessment)
                    end

    other_entries_milestone = LessonPlanMilestone.create_virtual("Other Items", other_entries)
    other_entries_milestone.previous_milestone = last_milestone
    other_entries_milestone
  end

  def self.create_prior_items_milestone(all_milestones, course, can_manage_mission, curr_user_course, manage_assessment)
    first_milestone = if all_milestones.length > 0 then
                        all_milestones[0]
                      else
                        nil
                      end

    if first_milestone
      entries_before_first = entries_between_date_range(nil, first_milestone.start_at, course, can_manage_mission, curr_user_course, manage_assessment)
      prior_entries_milestone = LessonPlanMilestone.create_virtual("Prior Items", entries_before_first)
      prior_entries_milestone.next_milestone = first_milestone
      prior_entries_milestone
    end
  end
end
