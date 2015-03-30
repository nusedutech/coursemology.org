class Assessment::GuidanceConceptStage < ActiveRecord::Base
  require 'csv'
  acts_as_paranoid

  attr_accessible :uncompleted_questions, :completed_answers, :disabled_topicconcept_id, :total_wrong, :total_right, :assessment_submission_id, :topicconcept_id, :failed
  validates_presence_of :assessment_submission_id, :topicconcept_id

  belongs_to :concept, class_name: Topicconcept, foreign_key: "topicconcept_id"
  belongs_to :disabled_concept, class_name: Topicconcept, foreign_key: "disabled_topicconcept_id"
  belongs_to :submission, class_name: Assessment::Submission, foreign_key: "assessment_submission_id"
  
  has_many :concept_edge_stages, class_name: Assessment::GuidanceConceptEdgeStage, dependent: :destroy, foreign_key: "assessment_guidance_concept_stage_id" 
  belongs_to :tag, class_name: Tag, foreign_key: "tag_id"
 
  scope :failed, -> { where(failed: true) }
  scope :passed, -> { where(failed: false) }

  def set_tag tag, course
    self.tag = tag
    self.save

    set_uncompleted_questions_string course
  end

  def set_uncompleted_questions_string course
    taggable_tags = self.concept.taggable_tags.question_type
    suitable_questions = []
    taggable_tags.each do |tagtag|
      #Only MCQ questions now
      if self.tag.nil?
        self.tag_id = nil
        question = course.questions.mcq_question.find_by_id(tagtag.taggable_id)
      else
        question = self.tag.mcq_questions.find_by_id(tagtag.taggable_id)
      end
      if question and !(Assessment::GuidanceQuizExcludedQuestion.is_excluded?(question))
        suitable_questions << question.id
      end
    end

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
    self.tag_id = nil
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

  def get_all_answers
    all_answers = []
    if !self.completed_answers.nil?
      all_answer_ids = CSV.parse_line(self.completed_answers)
      answer = nil
      all_answer_ids.each do |answer_id|
        answer = Assessment::Answer.where(as_answer_id: answer_id, as_answer_type: "Assessment::McqAnswer").first
        #Check in case questions are deleted
        if !answer.nil? and !answer.specific.question.nil?
          all_answers << answer
        else
          next
        end
      end
    end

    all_answers
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
      concept_edge_stage.add_one_wrong
    end

    if !pass_edge_lock
      pass_concept_edge_stages = Assessment::GuidanceConceptEdgeStage.get_passed_edge_stages submission, self, pass_edge_lock
      pass_concept_edge_stages.each do |concept_edge_stage|
        concept_edge_stage.add_one_wrong
      end
    end
  end

  def reset_statistics submission, pass_edge_lock
    self.total_wrong = 0
    self.total_right = 0
    self.save

    concept_edge_stages = Assessment::GuidanceConceptEdgeStage.get_edge_stages submission, self, pass_edge_lock
    concept_edge_stages.each do |concept_edge_stage|
      concept_edge_stage.reset_statistics
    end
  end

  #Check for current progress only criteria and lock if necessary
  #If no lock necessary, we check to unlock concept edge stages
  def check_to_lock submission, passing_edge_lock
    result = check_to_lock_procedure submission, passing_edge_lock

    if !result
      check_to_unlock_procedure submission, passing_edge_lock
    end

    result
  end

  def check_to_lock_procedure submission, passing_edge_lock
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
      #Only set to fail and lock if there is children to unlock
      if unlock_required_children submission, passing_edge_lock
        self.failed = true
        self.disabled_topicconcept_id = self.concept.id
        self.save
      else
        reset_statistics submission, passing_edge_lock
      end
      #Once found failed stage, delete all descendants/dependent entries
      cascade_delete_failed_content submission, passing_edge_lock

    elsif !result && self.failed
      self.failed = false
      self.save
    end

    result
  end

  #Check to unlock concept edge stages connected to current concept stage
  def check_to_unlock_procedure submission, passing_edge_lock
    result = []

    concept_edge_stages = Assessment::GuidanceConceptEdgeStage.get_edge_stages submission, self, passing_edge_lock
    concept_edge_stages.each do |concept_edge_stage|
      result = concept_edge_stage.check_to_unlock submission, passing_edge_lock
    end

    result
  end

  #Unlock required concept stages nodes when dependant concept fail
  #Return true if at least one node is unlocked
  def unlock_required_children submission, passing_edge_lock
    result = false

    required_edges = self.concept.concept_edge_required_concepts
    required_edges.each do |required_edge|
      if Assessment::GuidanceConceptEdgeOption.is_enabled? required_edge
        required_concept = required_edge.required_concept
        #At least one concept enabled set result to true 
        if Assessment::GuidanceConceptOption.is_enabled_with required_concept
          result = true
          concept_stage = Assessment::GuidanceConceptStage.get_passed_stage_simplified submission, required_concept.id

          #Only unlock if stage has not been unlocked (passed not found)
          if concept_stage.nil?
            concept_stage = Assessment::GuidanceConceptStage.get_failed_stage_simplified submission, required_concept.id
          
            #Only delete for if failed stage found
            if !concept_stage.nil?
              concept_stage.destroy
            end
            
            passed_stage = submission.concept_stages.new
            passed_stage.topicconcept_id = required_concept.id
            passed_stage.failed = false
            passed_stage.save

            #Create attempting edge stages after stage is created
            Assessment::GuidanceConceptEdgeStage.add_concept_edge_stages_from submission, passed_stage, concept.concept_edge_dependent_concepts
          else
            concept_stage.reset_statistics submission, passing_edge_lock
          end
        end
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
      processing_concept_stages |= Assessment::GuidanceConceptStage.cascade_delete_failed_concept_stage submission, current_concept_stage
    end
  end

  #Delete failed concept stage and return the next level of concepts
  def self.cascade_delete_failed_concept_stage submission, concept_stage
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

    def add_enabled_stages submission, create_new_option, passing_edge_lock
      concepts = submission.assessment.course.topicconcepts.concepts
      #Update concepts which are enabled
      if create_new_option
        concepts.each do |concept|
          concept_stage = submission.concept_stages.where(topicconcept_id: concept.id).first
          if concept_stage.nil? 
            add_enabled_stage submission, concept, passing_edge_lock
          end
        end
      end
    end

    #Check if a concept is activated for doing
    def add_enabled_stage submission, concept, passing_edge_lock
      if Assessment::GuidanceConceptOption.can_enter_with concept
        concept_stage = submission.concept_stages.new
        concept_stage.topicconcept_id = concept.id
        concept_stage.save
        
        #Rejuvenate edges related stages as well
        add_concept_edge_stages_from submission, concept_stage, concept.concept_edge_dependent_concepts, passing_edge_lock

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

    def get_stages submission, create_new_option, passing_edge_lock
      clean_deleted_stages submission
      add_enabled_stages submission, create_new_option, passing_edge_lock
      verify_failed_stages submission, passing_edge_lock
      submission.concept_stages.order('updated_at DESC')
    end

    def get_passed_stages submission, create_new_option, passing_edge_lock
      clean_deleted_stages submission
      add_enabled_stages submission, create_new_option, passing_edge_lock
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
      add_enabled_stages submission, create_new_option, passing_edge_lock
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
      add_enabled_stages submission, create_new_option, passing_edge_lock
      verify_failed_stages submission, passing_edge_lock

      concept_stage = submission.concept_stages.where(topicconcept_id: concept.id).first
      return concept_stage
    end

    def add_concept_edge_stages_from submission, concept_stage, concept_edges, passing_edge_lock
      concept_edges.each do |concept_edge|
        concept_edge_option = concept_edge.concept_edge_option
        if !concept_edge_option.nil? and concept_edge_option.enabled
          concept_edge_stage = concept_stage.concept_edge_stages.new
          concept_edge_stage.concept_edge_id = concept_edge.id
          concept_edge_stage.save
      
          #In case no criteria, we check to unlock edge pass status
          #Add bypass status to allow cascading to always follow
          concept_edge_stage.check_to_unlock submission, passing_edge_lock, true
        end
      end
    end
  end
end
