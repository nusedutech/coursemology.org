class Assessment::GuidanceConceptOption < ActiveRecord::Base
  acts_as_paranoid

  attr_accessible :enabled, :concept_edge_id
  validates_presence_of :concept_edge_id 

  belongs_to :concept_edge, class_name: ConceptEdge, foreign_key: "concept_edge_id"

  def self.enable
    self.enabled = true
    self.save
  end

  def self.disable
    self.enabled = false
    self.save
  end
end
