class Topicconcept < ActiveRecord::Base
  acts_as_paranoid
  attr_accessible :course_id, :deleted_at, :description, :name, :rank, :typename
  
  include Rails.application.routes.url_helpers
  
  scope :concepts, -> { where(:typename => "concept") }
  
  belongs_to :course  
  #belongs_to :creator, class_name: "User"
  
  has_many :links, class_name: "Link", foreign_key: "concept_id", dependent: :destroy
  has_many :concept_edge_dependent_concepts, class_name: "ConceptEdge", foreign_key: "required_id"
  has_many :dependent_concepts, :through => :concept_edge_dependent_concepts, class_name: "Topicconcept", foreign_key: "dependent_id"
  has_many :concept_edge_required_concepts, class_name: "ConceptEdge", foreign_key: "dependent_id"
  has_many :required_concepts, :through => :concept_edge_required_concepts, class_name: "Topicconcept", foreign_key: "required_id"
  
  has_many :topic_edge_parent_topics, class_name: "TopicEdge", foreign_key: "included_topic_concept_id"
  has_many :parent_topics, :through => :topic_edge_parent_topics, class_name: "Topicconcept", foreign_key: "parent_id"
  has_many :topic_edge_included_topicconcepts, class_name: "TopicEdge", foreign_key: "parent_id"
  has_many :included_topicconcepts, :through => :topic_edge_included_topicconcepts, class_name: "Topicconcept", :source => :included_topicconcept
  
  has_many :taggable_tags, as: :tag, dependent: :destroy
  has_many :questions, through: :taggable_tags, source: :taggable, source_type: "Assessment::Question"
end
