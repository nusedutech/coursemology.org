class Topicconcept < ActiveRecord::Base
  acts_as_paranoid
  attr_accessible :course_id, :deleted_at, :description, :name, :rank, :typename
  
  include Rails.application.routes.url_helpers
  
  scope :concepts, -> { where(:typename => "concept") }
  
  belongs_to :course  
  #belongs_to :creator, class_name: "User"
  
  has_many :links, class_name: "Link", foreign_key: "concept_id", dependent: :destroy
  has_many :concept_edge_dependent_concepts, class_name: "ConceptEdge", foreign_key: "required_id"
  has_many :dependent_concepts, :through => :concept_edge_dependent_concepts, class_name: "Topicconcept", foreign_key: "dependent_id"
  has_many :concept_edge_required_concepts, class_name: "ConceptEdge", foreign_key: "dependent_id"
  has_many :required_concepts, :through => :concept_edge_required_concepts, class_name: "Topicconcept", foreign_key: "required_id"
  
  has_many :topic_edge_parent_topics, class_name: "TopicEdge", foreign_key: "included_topic_concept_id"
  has_many :parent_topics, :through => :topic_edge_parent_topics, class_name: "Topicconcept", foreign_key: "parent_id"
  has_many :topic_edge_included_topicconcepts, class_name: "TopicEdge", foreign_key: "parent_id"
  has_many :included_topicconcepts, :through => :topic_edge_included_topicconcepts, class_name: "Topicconcept", :source => :included_topicconcept
  
  has_many :taggable_tags, as: :tag, dependent: :destroy
  has_many :forward_policy_levels, as: :forward_policy_theme, dependent: :destroy, class_name: "Assessment::ForwardPolicyLevel"
  has_many :questions, through: :taggable_tags, source: :taggable, source_type: "Assessment::Question"
  has_many :answers, through: :questions, source: :answers, class_name: Assessment::Answer
  has_many :mcq_answers, class_name: "Assessment::McqAnswer",
           through: :answers,
           source: :as_answer, source_type: "Assessment::McqAnswer"


  has_one :concept_option, class_name: Assessment::GuidanceConceptOption, dependent: :destroy, foreign_key: "topicconcept_id"

  def is_concept?
    self.typename == "concept"
  end

  def all_raw_correct_answer_attempts user_course = nil
    answers = []
    if user_course.nil?
      self.questions.each do |question|
        answers = answers + question.answers.where(correct: 1)
      end
    else
      self.questions.each do |question|
        answers = answers + question.answers.where(std_course_id: user_course, correct: 1)
      end
    end
    answers
  end

  def all_raw_wrong_answer_attempts user_course = nil
    answers = []
    if user_course.nil?     
      self.questions.find_each do |question|
        answers = answers + question.answers.where(correct: 0)
      end
    else
      self.questions.find_each do |question|
        answers = answers + question.answers.where(std_course_id: user_course, correct: 0)
      end
    end

    answers
  end

  def all_raw_correct_answer_attempts_from_guidance_quiz guidance_quiz, submission = nil
    answers = []

    if submission.nil?
      answers = self.mcq_answers.where("assessment_answers.correct = '1' AND assessment_answers.submission_id IN (?)", guidance_quiz.submissions)
    else
      answers = self.mcq_answers.where(assessment_answers: {submission_id: submission, correct: 1})
    end
    
    answers
  end

  def all_raw_wrong_answer_attempts_from_guidance_quiz guidance_quiz, submission = nil
    answers = []
    
    if submission.nil?
      answers = self.mcq_answers.where("assessment_answers.correct = '0' AND assessment_answers.submission_id IN (?)", guidance_quiz.submissions)
    else
      answers = self.mcq_answers.where(assessment_answers: {submission_id: submission, correct: 0})
    end

    answers
  end


  def all_latest_answer_attempts user_course = nil
    correctAnswers = []
    wrongAnswers = []

    if user_course.nil?     
      self.questions.each do |question|
        answers = question.answers.order('created_at DESC').limit(1)
        if answers.size == 1 and answers[0].correct
          correctAnswers << answers[0]
        elsif answers.size == 1 and !answers[0].correct
          wrongAnswers << answers[0]
        end
      end
    else
      self.questions.each do |question|
        answers = question.answers.where(std_course_id: user_course).order('created_at DESC').limit(1)
        if answers.size == 1 and answers[0].correct
          correctAnswers << answers[0]
        elsif answers.size == 1 and !answers[0].correct
          wrongAnswers << answers[0]
        end
      end
    end

    
    {
      correct: correctAnswers,
      wrong: wrongAnswers
    }
  end

  def all_optimistic_answer_attempts user_course = nil
    correctAnswers = []
    wrongAnswers = []

    if user_course.nil?     
      self.questions.find_each do |question|
        answers = question.answers.where(correct: 1).limit(1)
        if answers.size == 1
          correctAnswers << answers[0]
        else
          answers = question.answers.where(correct: 0).limit(1)
          if answers.size == 1
            wrongAnswers << answers[0]
          end
        end
        #correctAnswers = correctAnswers + answers
      end
    else
      self.questions.find_each do |question|
        answers = question.answers.where(std_course_id: user_course, correct: 1).limit(1)
        if answers.size == 1
          correctAnswers << answers[0]
        else
          answers = question.answers.where(std_course_id: user_course, correct: 0).limit(1)
          if answers.size == 1
            wrongAnswers << answers[0]
          end
        end
        #correctAnswers = correctAnswers + answers
      end
    end

    {
      correct: correctAnswers,
      wrong: wrongAnswers
    }
  end

  def all_pessimistic_answer_attempts user_course = nil
    correctAnswers = []
    wrongAnswers = []

    if user_course.nil?     
      self.questions.find_each do |question|
        answers = question.answers.where(correct: 0).limit(1)
        if answers.size == 1
          wrongAnswers << answers[0]
        else
          answers = question.answers.where(correct: 1).limit(1)
          if answers.size == 1
            correctAnswers << answers[0]
          end
        end
        #correctAnswers = correctAnswers + answers
      end
    else
      self.questions.find_each do |question|
        answers = question.answers.where(std_course_id: user_course, correct: 0).limit(1)
        if answers.size == 1
          wrongAnswers << answers[0]
        else
          answers = question.answers.where(std_course_id: user_course, correct: 1).limit(1)
          if answers.size == 1
            correctAnswers << answers[0]
          end
        end
        #correctAnswers = correctAnswers + answers
      end
    end

    {
      correct: correctAnswers,
      wrong: wrongAnswers
    }
  end
end
