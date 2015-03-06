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
  def check_to_unlock
    result = criteria_check
    
    if result && !self.passed
      self.passed = true
      self.save

    elsif !result && self.passed
      self.passed = false
      self.save
    end

    result
  end

  #Check if concept can be unlock and cascade the unlocking forward
  def cascade_unlock_dependent_concept_stage submission
    dependent_concept = self.concept_edge.dependent_concept
    next_cascading_target = nil

    #Only allow enabled concepts to be checked for unlocking
    #if Assessment::GuidanceConceptEdgeOption.is_enabled_with dependent_concept
      #dependent_concept_stage = Assessment::GuidanceConceptStage.get_passed_stage_simplified submission, dependent_concept.id
  
      #Only unlock if stage has not been unlocked
      #if dependent_concept_stage.nil?
        #required_concept_edges = dependent_concept.concept_edge_required_concepts - self.concept_edge

        #Make sure pre requisite criteria are all met
        #if concept_edges_check_all_criteria submission required_concept_edges
          #next_cascading_target = submission.concept_stages.new
          #next_cascading_target.topicconcept_id = dependent_concept.id
          #next_cascading_target.save
        #end
      #end
    #end
  end

  def cascade_delete_dependent_concept_stage

  end

  #Shorthand method to return true when all the concept edges sent in 
  #has met all the criteria assigned
  def concept_edges_check_all_criteria submission, concept_edges
    result = true
    #required_concept_edges.each do |concept_edge|
      #Only check for enabled edges when unlocking
      #if Assessment::GuidanceConceptEdgeOption.is_enabled? concept_edge
      	#concept_stage = Assessment::GuidanceConceptStage.get_passed_stage_simplified submission, concept_edge.required_concept_id
      	#Only check if the stage before this edge_stage is found and passed
      	#if concept_stage.nil?
      	  #result = false
      	  #break
      	#end

      	#concept_edge_stage = Assessment::GuidanceConceptEdgeStage.get_passed_stage_simplified concept_stage, concept_edge.id
		#if concept_edge_stage.nil?
          #result = false
		  #break
		#end
      #end
    #end
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
      if !concept_stage.failed
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

    def verify_passed_edge_stages concept_stage
      concept_stage.concept_edge_stages.each do |concept_edge_stage|
        verify_passed_edge_stage concept_edge_stage
      end
    end

    def verify_passed_edge_stage concept_edge_stage
      concept_edge_stage.check_to_unlock
    end

    def get_passed_edge_stages concept_stage
      clean_deleted_edge_stages concept_stage
      add_enabled_edge_stages concept_stage
      verify_passed_edge_stages concept_stage
      concept_stage.concept_edge_stages.passed.order('updated_at DESC')
    end

    def get_failed_edge_stages concept_stage
      clean_deleted_edge_stages concept_stage
      add_enabled_edge_stages concept_stage
      verify_passed_edge_stages concept_stage
      concept_stage.concept_edge_stages.failed.order('updated_at DESC')
    end

    def get_edge_stages concept_stage
      clean_deleted_edge_stages concept_stage
      add_enabled_edge_stages concept_stage
      verify_passed_edge_stages concept_stage
      concept_stage.concept_edge_stages.order('updated_at DESC')
    end

    def get_stage concept_stage, concept_edge
      clean_deleted_edge_stages concept_stage
      add_enabled_edge_stages concept_stage
      verify_passed_edge_stages concept_stage

      concept_edge_stage = concept_stage.concept_edge_stages.where(concept_edge_id: concept_edge.id).first
    end

    def get_passed_stage_simplified concept_stage, concept_edge_id
      concept_stage.concept_edge_stages.passed.where(concept_edge_id: concept_edge_id).first
    end
  end
end
