class Assessment::GuidanceQuizExcludedQuestion < ActiveRecord::Base
  acts_as_paranoid

  attr_accessible :excluded, :question_id
  validates_presence_of :question_id

  belongs_to :question, class_name: Assessment::Question, foreign_key: "assessment_question_id"

  def self.excluding(question)
    exclusion_status = question.exclusion_status
    if exclusion_status.nil?
      exclusion_status = Assessment::GuidanceQuizExcludedQuestion.new
      exclusion_status.question_id = question.id
    end

    exclusion_status.excluded = true
    exclusion_status.save!
  end

  def self.including(question)
    exclusion_status = question.exclusion_status
    if exclusion_status
      exclusion_status.excluded = false
      exclusion_status.save
    end
  end

  def cur_including
    self.excluded = false
    self.save
  end

  def self.excluded_questions(course)
    all_excluded_ids = course.exclusion_statuses.where("excluded = 1").map {|x| x.question_id}
    questions = []
    if all_excluded_ids.count > 0
      questions = course.questions.where("id in (?)", all_excluded_ids)
      questions.mcq_question
    else
      questions = []
    end
  end

  def self.included_questions(course)
    questions = []
    all_excluded_ids = course.exclusion_statuses.where("excluded = 1").map {|x| x.question_id}
    if all_excluded_ids.count > 0
      questions = course.questions.where("id not in (?)", all_excluded_ids)
    else
      questions = course.questions
    end
    questions.mcq_question
  end

end
