class ConceptEdge < ActiveRecord::Base
  attr_accessible :dependent_id, :required_id
  
  belongs_to :dependent_concept, class_name: "Topicconcept", foreign_key: "dependent_id"
  belongs_to :required_concept, class_name: "Topicconcept", foreign_key: "required_id"
end
