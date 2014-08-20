class TopicEdge < ActiveRecord::Base
  attr_accessible :included_topic_concept_id, :parent_id
  
  belongs_to :parent_topic, class_name: "Topicconcept", foreign_key: "parent_id"
  belongs_to :included_topicconcept, class_name: "Topicconcept", foreign_key: "included_topic_concept_id"
end
