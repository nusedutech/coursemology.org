class Assessment::GuidanceConceptEdgeStage < ActiveRecord::Base
  acts_as_paranoid

  attr_accessible :total_wrong, :total_right, :assessment_guidance_concept_stage_id, :concept_edge_id
  validates_presence_of :assessment_guidance_concept_stage_id, :concept_edge_id

  belongs_to :concept_edge, class_name: ConceptEdge, foreign_key: "concept_edge_id"
  belongs_to :concept_stage, class_name: Assessment::GuidanceConceptStage, foreign_key: "assessment_guidance_concept_stage_id"  
end
