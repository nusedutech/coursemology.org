class Assessment::GuidanceConceptEdgeStage < ActiveRecord::Base
  acts_as_paranoid

  attr_accessible :total_wrong, :total_right, :assessment_guidance_concept_stage_id, :concept_edge_id
  validates_presence_of :assessment_guidance_concept_stage_id, :concept_edge_id

  belongs_to :concept_edge, class_name: ConceptEdge, foreign_key: "concept_edge_id"
  belongs_to :concept_stage, class_name: Assessment::GuidanceConceptStage, foreign_key: "assessment_guidance_concept_stage_id"  

  scope :failed, -> { where(passed: false) }
  scope :passed, -> { where(passed: true) }

  def add_one_right rating
    self.total_right += 1
    self.rating_right += rating
    self.save
  end

  def add_one_wrong rating
    self.total_wrong += 1
    self.rating_wrong += rating
    self.save
  end

  def reset_statistics
    self.total_right = 0
    self.total_wrong = 0   
    self.rating_right = 0
    self.rating_wrong = 0
    self.passed = criteria_check
    self.save
  end
  
  def criteria_check
  	passing_criteria = self.concept_edge.concept_edge_option.concept_edge_criteria
  	result = true
    if passing_criteria.count > 0
      #Check all failing criteria
      passing_criteria.each do |criterion|
        case (criterion.specific.is_type)
          when "correct_threshold"
            pass_intermediate = criterion.specific.evaluate self.total_right
          when "correct_rating_threshold"
            pass_intermediate = criterion.specific.evaluate self.rating_right, self.rating_wrong
          when "correct_percent_threshold"
            pass_intermediate = criterion.specific.evaluate self.total_right, self.total_wrong
        end

        if !pass_intermediate
          result = false
          break
        end
      end
    end
    result
  end

  def criteria_check_and_save
    self.passed = criteria_check
    self.save
  end

  #Check for current progress on criteria and unlock if necessary
  #Return the concepts unlocked
  def check_to_unlock submission, bypass_archive_check = false
    result = []
    criteria_result = criteria_check

    if criteria_result && (!self.passed or bypass_archive_check)
      self.passed = true
      self.save
      result = cascade_unlock_loop submission, self.concept_edge.dependent_concept

    elsif !criteria_result && (self.passed or bypass_archive_check)
      self.passed = false
      self.save
      dependent_concept = self.concept_edge.dependent_concept
      dependent_concept_stage = Assessment::GuidanceConceptStage.get_stage_simplified submission, dependent_concept.id
      Assessment::GuidanceConceptStage.cascade_delete_loop submission, dependent_concept_stage
    end

    result
  end

  #Check for current progress and lock and unlock whenever necessary
  def check_to_unlock_for_data_synchronisation submission 
    result = []
    criteria_result = criteria_check
    dependent_concept = self.concept_edge.dependent_concept
    dependent_concept_stage = Assessment::GuidanceConceptStage.get_passed_stage_simplified submission, dependent_concept.id

    #If pass, check for next concept stage
    # - delete if it is available (in case some other edge criteria not fulfiled)
    # - add if it is not available (in case it can be added)
    if criteria_result
      self.passed = true
      self.save
      if dependent_concept_stage.nil?
        cascade_unlock_loop submission, self.concept_edge.dependent_concept
      else
        Assessment::GuidanceConceptStage.cascade_delete_loop submission, dependent_concept_stage
      end
    #If fail, just send for delete
    else
      self.passed = false
      self.save
      Assessment::GuidanceConceptStage.cascade_delete_loop submission, dependent_concept_stage
    end
  end
 
  #Returns all the concepts that were unlocked
  def cascade_unlock_loop submission, dependent_concept
    dependent_concepts = [dependent_concept]
    result = []

    while dependent_concepts.size > 0 do
      current_concept = dependent_concepts.shift

      temp_result = cascade_unlock_dependent_concept_stage submission, current_concept
      dependent_concepts |= temp_result[:cascade_targets]

      if temp_result[:unlock_status]    
        result << current_concept
      end
    end

    result
  end

  #Check if concept can be unlock and cascade the unlocking forward
  #Return all the dependent concepts of the unlocked concept (if unlocking occured)
  #Also return whether the unlocking was done sucessfully
  def cascade_unlock_dependent_concept_stage submission, dependent_concept
    next_cascading_targets = []
    unlock_status = false

    #Only allow enabled concepts to be checked for unlocking
    if Assessment::GuidanceConceptOption.is_enabled_with dependent_concept
      dependent_concept_stage = Assessment::GuidanceConceptStage.get_passed_stage_simplified submission, dependent_concept.id

      #Only unlock if stage has not been unlocked (passed not found)
      if dependent_concept_stage.nil?
        required_concept_edges = dependent_concept.concept_edge_required_concepts

        #Make sure pre requisite criteria are all met
        if Assessment::GuidanceConceptEdgeStage.concept_edges_check_all_criteria submission, required_concept_edges
          dependent_concept_stage = Assessment::GuidanceConceptStage.get_failed_stage_simplified submission, dependent_concept.id
          
          #Only delete for if failed stage found
      	  if !dependent_concept_stage.nil?
            dependent_concept_stage.destroy
      	  end

          passed_stage = submission.concept_stages.new
          passed_stage.topicconcept_id = dependent_concept.id
          passed_stage.failed = false
          passed_stage.save

          unlock_status = true

          #Create attempting edge stages after stage is created
          Assessment::GuidanceConceptEdgeStage.add_concept_edge_stages_from submission, passed_stage, dependent_concept.concept_edge_dependent_concepts

          #Get the next level of concepts to check for unlocking
          next_cascading_targets = dependent_concept.dependent_concepts
        end
      end
    end

    {
      cascade_targets: next_cascading_targets, 
      unlock_status: unlock_status
    }
  end

  def self.add_concept_edge_stages_from submission, concept_stage, concept_edges
    concept_edges.each do |concept_edge|
      concept_edge_option = concept_edge.concept_edge_option
      if !concept_edge_option.nil? and concept_edge_option.enabled
        concept_edge_stage = concept_stage.concept_edge_stages.new
        concept_edge_stage.concept_edge_id = concept_edge.id
        concept_edge_stage.save

        result = concept_edge_stage.criteria_check
        #In case no criteria, we check to unlock edge pass status
        if result
	        concept_edge_stage.passed = true
	        concept_edge_stage.save
	      end
      end
    end
  end

  #Shorthand method to return true when all the concept edges sent in 
  #has met all the criteria assigned
  def self.concept_edges_check_all_criteria submission, concept_edges
    result = true
    concept_edges.each do |concept_edge|
      #Only check for enabled edges when unlocking
      if (Assessment::GuidanceConceptEdgeOption.is_enabled? concept_edge) and 
         (Assessment::GuidanceConceptOption.is_enabled_with concept_edge.required_concept)
      	concept_stage = Assessment::GuidanceConceptStage.get_passed_stage_simplified submission, concept_edge.required_concept.id
      	#Only check if the stage before this edge_stage is found and passed
      	if concept_stage.nil?
      	  result = false
      	  break
      	end

      	concept_edge_stage = Assessment::GuidanceConceptEdgeStage.get_passed_stage_simplified concept_stage, concept_edge.id
		    if concept_edge_stage.nil?
          result = false
		      break
		    end
      end
    end
  end

  #Static methods declare here
  #For retrieving collection or member units
  #Remember to clean deleted entries first
  class << self
    def clean_deleted_edge_stages concept_stage
      concept_edge_stages = concept_stage.concept_edge_stages
      concept_edge_stages.each do |concept_edge_stage|
        clean_deleted_edge_stage concept_edge_stage
      end
    end

    def clean_deleted_edge_stage concept_edge_stage
      concept_edge = concept_edge_stage.concept_edge

      if concept_edge.nil? or 
         (Assessment::GuidanceConceptEdgeOption.is_not_enabled? concept_edge)
        concept_edge_stage.destroy

        return true
      else
        return false
      end
    end

    def add_enabled_edge_stages concept_stage
      if !concept_stage.failed and concept_stage.deleted_at.nil?
        concept_edges =  concept_stage.concept.concept_edge_dependent_concepts
        concept_edges.each do |concept_edge|
          concept_edge_stage = concept_stage.concept_edge_stages.where(concept_edge_id: concept_edge.id).first
          if concept_edge_stage.nil? and
             Assessment::GuidanceConceptEdgeOption.is_enabled? concept_edge
            add_enabled_edge_stage concept_stage, concept_edge
          end
        end
      end
    end

    def add_enabled_edge_stage concept_stage, concept_edge
      if Assessment::GuidanceConceptEdgeOption.is_enabled? concept_edge
        concept_edge_stage = concept_stage.concept_edge_stages.new
        concept_edge_stage.concept_edge_id = concept_edge.id
        concept_edge_option = concept_edge.concept_edge_option
        concept_edge_stage.save

        return concept_edge_stage
      else
        return nil
      end
    end

    def verify_passed_edge_stages submission, concept_stage
      concept_stage.concept_edge_stages.each do |concept_edge_stage|
        concept_edge_stage.check_to_unlock_for_data_synchronisation submission
      end
    end

    def data_synchronisation_clean submission, concept_stages
      concept_stages.each do |concept_stage|
        clean_deleted_edge_stages concept_stage
      end
    end

    def data_synchronisation_add submission, concept_stages
      concept_stages.each do |concept_stage|
        add_enabled_edge_stages concept_stage
      end
    end

    def data_synchronisation_verify submission, concept_stages
      concept_stages.each do |concept_stage|
        verify_passed_edge_stages submission, concept_stage
      end
    end

    def get_passed_edge_stages concept_stage
      concept_stage.concept_edge_stages.passed.order('updated_at DESC')
    end

    def get_failed_edge_stages concept_stage
      concept_stage.concept_edge_stages.failed.order('updated_at DESC')
    end

    def get_edge_stages concept_stage
      concept_stage.concept_edge_stages.order('updated_at DESC')
    end

    def get_stage concept_stage, concept_edge
      concept_edge_stage = concept_stage.concept_edge_stages.where(concept_edge_id: concept_edge.id).first
    end

    def get_passed_stage_simplified concept_stage, concept_edge_id
      concept_stage.concept_edge_stages.passed.where(concept_edge_id: concept_edge_id).first
    end

    def get_edge_stages_simplified concept_stage
      concept_stage.concept_edge_stages
    end
  end
end
