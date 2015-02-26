class Assessment::GuidanceConceptStage < ActiveRecord::Base
  acts_as_paranoid

  attr_accessible :uncompleted_questions, :completed_answers, :disabled_topicconcept_id, :total_wrong, :total_right, :assessment_submission_id, :topicconcept_id, :failed
  validates_presence_of :assessment_submission_id, :topicconcept_id

  belongs_to :concept, class_name: Topicconcept, foreign_key: "topicconcept_id"

  belongs_to :disabled_concept, class_name: Topicconcept, foreign_key: "disabled_topicconcept_id"

  belongs_to :submission, class_name: Assessment::Submission, foreign_key: "assessment_submission_id"
  
  has_many :concept_edge_stages, class_name: Assessment::GuidanceConceptEdgeStage, dependent: :destroy, foreign_key: "assessment_guidance_concept_stage_id" 
 
  scope :failed, -> { where(failed: true) }
  scope :passed, -> { where(failed: false) }
  
  def get_all_questions_string(guidance_quiz, course)
    questions = self.concept.taggable_tags.collect(&:question)
    suitable_questions = []
    questions.each do |question| 
      if !(Assessment::GuidanceQuizExcludedQuestion.is_excluded?(question))
        suitable_questions << question
      end
    end

    if suitable_questions.count > 0
      result = questions.shuffle.join(",")
    else 
      result = nil
    end

    result
  end

  def allQuestions = CSV.parse_line(self.uncompleted_questions)
    #We will only use line 0 so check line 0 only
    if allQuestions == nil || allQuestions.nil?
      policyLevel = self.getCorrespondingLevel
      newQuestions = policyLevel.getAllQuestionsString assessment
      self.uncompleted_questions = newQuestions
      self.save
      allQuestions = CSV.parse_line(newQuestions)
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
