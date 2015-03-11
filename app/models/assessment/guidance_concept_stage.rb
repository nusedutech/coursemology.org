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

  #Accelerated function to get first id out
  def get_top_question_id_fast
    if self.uncompleted_questions.nil? or self.uncompleted_questions == ""
      result = nil
    else
      all_questions = CSV.parse_line(self.uncompleted_questions)
      result = all_questions.shift
    end
    
    return result
  end

  def reset_and_get_top_question course
    self.set_uncompleted_questions_string course

    if self.uncompleted_questions.nil?
      result = nil
    else
      all_questions = CSV.parse_line(self.uncompleted_questions)
      question_id = all_questions.shift
      result = course.questions.find_by_id(question_id)
    end
    return result
  end

  def get_top_question course
    if self.uncompleted_questions.nil? or self.uncompleted_questions == ""
      self.set_uncompleted_questions_string course
    end
    
    #If still empty after refreshing
    if self.uncompleted_questions.nil? or self.uncompleted_questions == ""
      result = nil
    else
      all_questions = CSV.parse_line(self.uncompleted_questions)
      question_id = all_questions.shift
      result = course.questions.find_by_id(question_id)
    end
    return result
  end

  def remove_top_question
    all_questions = CSV.parse_line(self.uncompleted_questions)
    all_questions.shift
    self.uncompleted_questions = all_questions.join(",")
    self.save
  end

  def record_answer(answer_id)
    if self.completed_answers.present?
      all_answers = CSV.parse_line(self.completed_answers)
    else
      all_answers = []
    end
    all_answers.concat([answer_id])

    self.completed_answers = all_answers.join(",")
    self.save
  end

  def add_one_right submission, pass_edge_lock
    self.total_right += 1
    self.save

    concept_edge_stages = Assessment::GuidanceConceptEdgeStage.get_failed_edge_stages submission, self, pass_edge_lock
    concept_edge_stages.each do |concept_edge_stage|
      concept_edge_stage.add_one_right
    end

    if !pass_edge_lock
      pass_concept_edge_stages = Assessment::GuidanceConceptEdgeStage.get_passed_edge_stages submission, self, pass_edge_lock
      pass_concept_edge_stages.each do |concept_edge_stage|
        concept_edge_stage.add_one_right
      end
    end
  end

  def add_one_wrong submission, pass_edge_lock
    self.total_wrong += 1
    self.save

    concept_edge_stages = Assessment::GuidanceConceptEdgeStage.get_failed_edge_stages submission, self, pass_edge_lock
    concept_edge_stages.each do |concept_edge_stage|
      concept_edge_stage.add_one_right
    end

    if !pass_edge_lock
      pass_concept_edge_stages = Assessment::GuidanceConceptEdgeStage.get_passed_edge_stages submission, self, pass_edge_lock
      pass_concept_edge_stages.each do |concept_edge_stage|
        concept_edge_stage.add_one_right
      end
    end
  end

  #Check for current progress only criteria and lock if necessary
  #If no lock necessary, we check to unlock concept edge stages
  def check_to_lock submission, passing_edge_lock
    failing_criteria = self.concept.concept_option.concept_criteria

    if failing_criteria.count > 0
      result = true
      #Check all failing criteria
      failing_criteria.each do |criterion|
        case (criterion.specific.is_type)
          when "wrong_threshold"
            pass_intermediate = criterion.specific.evaluate self.total_wrong
        end

        if pass_intermediate
          result = false
          break
        end
      end
    else
      result = false
    end

    if result && !self.failed
      self.failed = true
      self.disabled_topicconcept_id = self.concept.id
      self.save
      #Once found failed stage, delete all descendants/dependent entries
      cascade_delete_failed_content submission, passing_edge_lock

    elsif !result && self.failed
      self.failed = false
      self.save
    end

    if !result
      concept_edge_stages = Assessment::GuidanceConceptEdgeStage.get_edge_stages submission, self, passing_edge_lock
      concept_edge_stages.each do |concept_edge_stage|
        concept_edge_stage.check_to_unlock submission, passing_edge_lock
      end
    end

    result
  end

  def cascade_delete_failed_content submission, passing_edge_lock
    #Must call static updater at least once before CRUD
    concept_edge_stages_list = Assessment::GuidanceConceptEdgeStage.get_edge_stages submission, self, passing_edge_lock
    processing_concept_stages = []

    #Get next level of concept_stages for deleting
    concept_edge_stages_list.each do |current_edge_stage|
      dependent_concept = current_edge_stage.concept_edge.dependent_concept
      dependent_concept_stage = Assessment::GuidanceConceptStage.get_stage_simplified submission, dependent_concept.id

      #Check for null and circular dependency (to prevent infinite recursion)
      if !dependent_concept_stage.nil? and dependent_concept_stage != self
        processing_concept_stages << dependent_concept_stage
      end
    end
    
    #Delete all edges as not required anymore
    concept_edge_stages.map(&:destroy)

    #Iteratively find the lower level concepts and delete the content
    while processing_concept_stages.size > 0 do
      current_concept_stage = processing_concept_stages.shift
      processing_concept_stages |= Assessment::GuidanceConceptStage.cascade_delete_failed_concept_stage current_concept_stage
    end
  end

  #Delete failed concept stage and return the next level of concepts
  def self.cascade_delete_failed_concept_stage concept_stage
    concept_edge_stages_list = Assessment::GuidanceConceptEdgeStage.get_edge_stages_simplified concept_stage
    processing_concept_stages = []

    concept_edge_stages_list.each do |current_edge_stage|
      dependent_concept = current_edge_stage.concept_edge.dependent_concept
      dependent_concept_stage = self.get_stage_simplified submission, dependent_concept.id

      #Check for null and circular dependency (to prevent infinite recursion)
      if !dependent_concept_stage.nil? and 
         dependent_concept_stage != self and 
         dependent_concept_stage != concept_stage
        processing_concept_stages << dependent_concept_stage
      end
    end

    #Destroy concept_stage and all related stages once done
    concept_stage.destroy

    processing_concept_stages
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

    def add_enabled_stages submission, create_new_option
      concepts = submission.assessment.course.topicconcepts.concepts
      #Update concepts which are enabled
      if create_new_option
        concepts.each do |concept|
          concept_stage = submission.concept_stages.where(topicconcept_id: concept.id).first
          if concept_stage.nil? 
            add_enabled_stage submission, concept
          end
        end
      end
    end

    #Check if a concept is activated for doing
    def add_enabled_stage submission, concept
      if Assessment::GuidanceConceptOption.can_enter_with concept
        concept_stage = submission.concept_stages.new
        concept_stage.topicconcept_id = concept.id
        concept_stage.save

        #Rejuvenate edges related stages as well
        add_concept_edge_stages_from submission, concept_stage, concept.concept_edge_dependent_concepts

        return concept_stage
      else
        return nil
      end
    end

    def verify_failed_stages submission, passing_edge_lock
      submission.concept_stages.each do |concept_stage|
        verify_failed_stage submission, concept_stage, passing_edge_lock
      end
    end

    def verify_failed_stage submission, concept_stage, passing_edge_lock
      concept_stage.check_to_lock submission, passing_edge_lock
    end

    def get_passed_stages submission, create_new_option, passing_edge_lock
      clean_deleted_stages submission
      add_enabled_stages submission, create_new_option
      verify_failed_stages submission, passing_edge_lock
      submission.concept_stages.passed.order('updated_at DESC')
    end

    def get_failed_stages submission, passing_edge_lock
      clean_deleted_stages submission
      verify_failed_stages submission, passing_edge_lock
      submission.concept_stages.failed.order('updated_at DESC')
    end

    def get_passed_stage submission, concept, create_new_option, passing_edge_lock
      clean_deleted_stages submission
      add_enabled_stages submission, create_new_option
      verify_failed_stages submission, passing_edge_lock

      concept_stage = submission.concept_stages.passed.where(topicconcept_id: concept.id).first
      return concept_stage
    end

    #Simiplified get passed stages implementation with 0 checks
    #Assume that you have already called the adding, deleting
    #and fail verification checks to synchronise with the
    #concept map implementation
    def get_passed_stage_simplified submission, concept_id
      submission.concept_stages.passed.where(topicconcept_id: concept_id).first
    end

    def get_failed_stage_simplified submission, concept_id
      submission.concept_stages.failed.where(topicconcept_id: concept_id).first
    end

    def get_stage_simplified submission, concept_id
      submission.concept_stages.where(topicconcept_id: concept_id).first
    end

    def get_latest_passed_stage submission, passing_edge_lock
      clean_deleted_stages submission
      verify_failed_stages submission, passing_edge_lock

      concept_stage = submission.concept_stages.passed.order('updated_at DESC').first
      return concept_stage
    end

    def get_stage submission, concept, create_new_option, passing_edge_lock
      clean_deleted_stages submission
      add_enabled_stages submission, create_new_option
      verify_failed_stages submission, passing_edge_lock

      concept_stage = submission.concept_stages.where(topicconcept_id: concept.id).first
      return concept_stage
    end

    def add_concept_edge_stages_from submission, concept_stage, concept_edges
      concept_edges.each do |concept_edge|
        concept_edge_option = concept_edge.concept_edge_option
        if !concept_edge_option.nil? and concept_edge_option.enabled
          concept_edge_stage = concept_stage.concept_edge_stages.new
          concept_edge_stage.concept_edge_id = concept_edge.id
          concept_edge_stage.save

          #In case no criteria, we check to unlock edge pass status
          concept_edge_stage.check_to_unlock submission
        end
      end
    end
  end
end
