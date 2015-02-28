class Assessment::GuidanceConceptStage < ActiveRecord::Base
  require 'csv'
  acts_as_paranoid

  attr_accessible :uncompleted_questions, :completed_answers, :disabled_topicconcept_id, :total_wrong, :total_right, :assessment_submission_id, :topicconcept_id, :failed
  validates_presence_of :assessment_submission_id, :topicconcept_id

  belongs_to :concept, class_name: Topicconcept, foreign_key: "topicconcept_id"

  belongs_to :disabled_concept, class_name: Topicconcept, foreign_key: "disabled_topicconcept_id"

  belongs_to :submission, class_name: Assessment::Submission, foreign_key: "assessment_submission_id"
  
  has_many :concept_edge_stages, class_name: Assessment::GuidanceConceptEdgeStage, dependent: :destroy, foreign_key: "assessment_guidance_concept_stage_id" 
 
  scope :failed, -> { where(failed: true) }
  scope :passed, -> { where(failed: false) }
  
  def set_uncompleted_questions_string course
    taggable_tags = self.concept.taggable_tags.question_type
    suitable_questions = []
    taggable_tags.each do |tagtag|
      #Only MCQ questions now
      question = course.questions.mcq_question.find_by_id(tagtag.taggable_id)
      if question and !(Assessment::GuidanceQuizExcludedQuestion.is_excluded?(question))
        suitable_questions << question.id
      end
    end

    suitable_questions
    if suitable_questions.count > 0
      result = suitable_questions.shuffle.join(",")
    else 
      result = nil
    end
    
    self.uncompleted_questions = result
    self.save
  end

  def get_top_question course
    if self.uncompleted_questions.nil?
      self.set_uncompleted_questions_string course
    end
    
    #If still empty after refreshing
    if self.uncompleted_questions.nil?
      result = nil
    else
      all_questions = CSV.parse_line(self.uncompleted_questions)
      question_id = all_questions.shift
      todo_question = course.questions.find_by_id(question_id)
    end
  end

  #Static methods declare here
  #For retrieving collection or member units
  #Remember to clean deleted entries first
  class << self
    def clean_deleted_stages submission
      concept_stages = submission.concept_stages
      concept_stages.each do |concept_stage|
        concept = concept_stage.concept
        #Update concepts which are deleted or disabled are removed at once
        if concept.nil? or 
           concept.concept_option.nil? or 
           !concept.concept_option.enabled
          concept_stage.destroy
        end
      end
    end

    def get_passed_stages submission
      clean_deleted_stages submission
      submission.concept_stages.passed.order('updated_at DESC')
    end

    def get_failed_stages submission
      clean_deleted_stages submission
      submission.concept_stages.failed.order('updated_at DESC')
    end

    def clean_deleted_stage concept_stage
      concept = concept_stage.concept
      #Update concepts which are deleted or disabled are removed at once
      if concept.nil? or 
         concept.concept_option.nil? or 
         !concept.concept_option.enabled
        concept_stage.destroy
        return true
      else
        return false
      end
    end

    def get_passed_stage submission, concept_id
      concept_stage = submission.concept_stages.passed
                                               .where(topicconcept_id: concept_id)
                                               .first
      if concept_stage.nil? or clean_deleted_stage concept_stage
        return nil
      else
        return concept_stage
      end
    end

    def get_latest_passed_stage submission
      concept_stage = submission.concept_stages.passed.order('updated_at DESC').first
      if concept_stage.nil? or clean_deleted_stage concept_stage
        return nil
      else
        return concept_stage
      end
    end

    def get_stage submission, concept_id
      concept_stage = submission.concept_stages.where(topicconcept_id: concept_id)
                                               .first
      if concept_stage.nil? or clean_deleted_stage concept_stage
        return nil
      else
        return concept_stage
      end
    end
  end
end
