class ConceptEdge < ActiveRecord::Base
  attr_accessible :dependent_id, :required_id
  
  belongs_to :dependent_concept, class_name: "Topicconcept", foreign_key: "dependent_id"
  belongs_to :required_concept, class_name: "Topicconcept", foreign_key: "required_id"

  has_one :concept_edge_option, class_name: Assessment::GuidanceConceptEdgeOption, dependent: :destroy, foreign_key: "concept_edge_id"

  amoeba do
    include_field [:concept_edge_option]
  end
end
