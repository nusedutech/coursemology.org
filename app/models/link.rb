class Link < ActiveRecord::Base
  attr_accessible :concept_id, :deleted_at, :link
  
  belongs_to :topicconcept, class_name: "Topicconcept", foreign_key: "concept_id"
end
