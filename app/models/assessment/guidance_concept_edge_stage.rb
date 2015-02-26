class Assessment::GuidanceConceptEdgeStage < ActiveRecord::Base
  acts_as_paranoid

  attr_accessible :total_wrong, :total_right, :assessment_guidance_concept_stage_id, :concept_edge_id
  validates_presence_of :assessment_guidance_concept_stage_id, :concept_edge_id

  belongs_to :concept_edge, class_name: ConceptEdge, foreign_key: "concept_edge_id"
  belongs_to :concept_stage, class_name: Assessment::GuidanceConceptStage, foreign_key: "assessment_guidance_concept_stage_id"  

  scope :failed, -> { where(passed: false) }
  scope :passed, -> { where(passed: true) }

  #Static methods declare here
  #For retrieving collection or member units
  #Remember to clean deleted entries first
  class << self
    def clean_deleted_edge_stages concept_stage
      concept_edge_stages = concept_stage.concept_edge_stages
      concept_edge_stages.each do |concept_edge_stage|
        concept_edge = concept_edge_stage.concept_edge
        if concept_edge.nil? or 
           concept_edge.concept_edge_option.nil? or 
           !concept_edge.concept_edge_option.enabled
          concept_edge_stage.destroy
        end
      end
    end

    def get_passed_edge_stages concept_stage
      clean_deleted_edge_stages concept_stage
      concept_stage.concept_edge_stages.passed.order('updated_at DESC')
    end

    def get_failed_edge_stages concept_stage
      clean_deleted_edge_stages concept_stage
      concept_stage.concept_edge_stages.failed.order('updated_at DESC')
    end
  end
end
