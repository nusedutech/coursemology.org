class Assessment::GuidanceConceptEdgeStage < ActiveRecord::Base
  acts_as_paranoid

  attr_accessible :total_wrong, :total_right, :assessment_guidance_concept_stage_id, :concept_edge_id
  validates_presence_of :assessment_guidance_concept_stage_id, :concept_edge_id

  belongs_to :concept_edge, class_name: ConceptEdge, foreign_key: "concept_edge_id"
  belongs_to :concept_stage, class_name: Assessment::GuidanceConceptStage, foreign_key: "assessment_guidance_concept_stage_id"  

  scope :failed, -> { where(passed: false) }
  scope :passed, -> { where(passed: true) }

  def add_one_right
    self.total_right += 1
    self.save
  end

  def add_one_wrong
    self.total_wrong += 1
    self.save
  end

  def reset_statistics
    self.total_right = 0
    self.total_wrong = 0
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
        end

        if !pass_intermediate
          result = false
          break
        end
      end
    end
    result
  end

  #Check for current progress on criteria and unlock if necessary
  def check_to_unlock submission, passing_edge_lock, bypass_archive_check = false
    result = criteria_check
    
    if result && (!self.passed or bypass_archive_check)
      self.passed = true
      self.save
      cascade_unlock_loop submission, self.concept_edge.dependent_concept

    elsif !result && (self.passed or bypass_archive_check)
      self.passed = false
      self.save
      dependent_concept = self.concept_edge.dependent_concept
      dependent_concept_stage = Assessment::GuidanceConceptStage.get_stage_simplified submission, dependent_concept.id
      #Check for null and circular dependency (to prevent infinite recursion)
      if !dependent_concept_stage.nil?
        processing_concept_stages = [dependent_concept_stage]
	    #Iteratively find the lower level concepts and delete the content
	    while processing_concept_stages.size > 0 do
	      current_concept_stage = processing_concept_stages.shift
	      processing_concept_stages |= Assessment::GuidanceConceptStage.cascade_delete_failed_concept_stage submission, current_concept_stage
	    end
      end
    end

    result
  end
 
  def cascade_unlock_loop submission, dependent_concept
    dependent_concepts = [dependent_concept]

    while dependent_concepts.size > 0 do
      new_cascade_targets = cascade_unlock_dependent_concept_stage submission, dependent_concepts.shift
      dependent_concepts |= new_cascade_targets
    end
  end

  #Check if concept can be unlock and cascade the unlocking forward
  #Return all the dependent concepts of the unlocked concept (if unlocking occured)
  def cascade_unlock_dependent_concept_stage submission, dependent_concept
    next_cascading_targets = []

    #Only allow enabled concepts to be checked for unlocking
    if Assessment::GuidanceConceptOption.is_enabled_with dependent_concept
      dependent_concept_stage = Assessment::GuidanceConceptStage.get_passed_stage_simplified submission, dependent_concept.id

      #Only unlock if stage has not been unlocked (passed not found)
      if dependent_concept_stage.nil?
        required_concept_edges = dependent_concept.concept_edge_required_concepts

        #Make sure pre requisite criteria are all met
        if concept_edges_check_all_criteria submission, required_concept_edges
          dependent_concept_stage = Assessment::GuidanceConceptStage.get_failed_stage_simplified submission, dependent_concept.id
          
          #Only delete for if failed stage found
      	  if !dependent_concept_stage.nil?
            dependent_concept_stage.destroy
      	  end

          passed_stage = submission.concept_stages.new
          passed_stage.topicconcept_id = dependent_concept.id
          passed_stage.failed = false
          passed_stage.save

          #Create attempting edge stages after stage is created
          Assessment::GuidanceConceptEdgeStage.add_concept_edge_stages_from submission, passed_stage, dependent_concept.concept_edge_dependent_concepts

          #Get the next level of concepts to check for unlocking
          next_cascading_targets = dependent_concept.dependent_concepts
        end
      end
    end

    next_cascading_targets
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
  def concept_edges_check_all_criteria submission, concept_edges
    result = true
    concept_edges.each do |concept_edge|
      #Only check for enabled edges when unlocking
      if (Assessment::GuidanceConceptEdgeOption.is_enabled? concept_edge) and (Assessment::GuidanceConceptOption.is_enabled_with concept_edge.required_concept)
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
         concept_edge.concept_edge_option.nil? or 
         !concept_edge.concept_edge_option.enabled
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
          if concept_edge_stage.nil?
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
        if concept_edge_option.concept_edge_criteria.count == 0
          concept_edge_stage.passed = true
        end
        concept_edge_stage.save

        return concept_edge_stage
      else
        return nil
      end
    end

    def verify_passed_edge_stages submission, concept_stage, passing_edge_lock
      concept_stage.concept_edge_stages.each do |concept_edge_stage|
        verify_passed_edge_stage submission, concept_edge_stage, passing_edge_lock
      end
    end

    def verify_passed_edge_stage submission, concept_edge_stage, passing_edge_lock
      concept_edge_stage.check_to_unlock submission, passing_edge_lock
    end

    def get_passed_edge_stages submission, concept_stage, passing_edge_lock
      clean_deleted_edge_stages concept_stage
      add_enabled_edge_stages concept_stage
      verify_passed_edge_stages submission, concept_stage, passing_edge_lock
      concept_stage.concept_edge_stages.passed.order('updated_at DESC')
    end

    def get_failed_edge_stages submission, concept_stage, passing_edge_lock
      clean_deleted_edge_stages concept_stage
      add_enabled_edge_stages concept_stage
      verify_passed_edge_stages submission, concept_stage, passing_edge_lock
      concept_stage.concept_edge_stages.failed.order('updated_at DESC')
    end

    def get_edge_stages submission, concept_stage, passing_edge_lock
      clean_deleted_edge_stages concept_stage
      add_enabled_edge_stages concept_stage
      verify_passed_edge_stages submission, concept_stage, passing_edge_lock
      concept_stage.concept_edge_stages.order('updated_at DESC')
    end

    def get_stage submission, concept_stage, concept_edge, passing_edge_lock
      clean_deleted_edge_stages concept_stage
      add_enabled_edge_stages concept_stage
      verify_passed_edge_stages submission, concept_stage, passing_edge_lock

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
