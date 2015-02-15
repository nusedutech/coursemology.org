class ConceptEdge < ActiveRecord::Base
  attr_accessible :dependent_id, :required_id
  
  belongs_to :dependent_concept, class_name: "Topicconcept", foreign_key: "dependent_id"
  belongs_to :required_concept, class_name: "Topicconcept", foreign_key: "required_id"

  has_one :guidance_concept_option, class_name: Assessment::GuidanceConceptOption, dependent: :destroy
end
