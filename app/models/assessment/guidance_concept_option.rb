class Assessment::GuidanceConceptOption < ActiveRecord::Base
  acts_as_paranoid

  attr_accessible :enabled, :concept_edge_id
  validates_presence_of :concept_edge_id 

  belongs_to :concept_edge, class_name: ConceptEdge, foreign_key: "concept_edge_id"
  has_many :concept_criteria, class_name: Assessment::GuidanceConceptCriterion, dependent: :destroy

  def self.enable(concept_edge)
    enable_status = concept_edge.concept_option
    if enable_status.nil?
      enable_status = Assessment::GuidanceConceptOption.new
      enable_status.concept_edge_id = concept_edge.id
    end

    enable_status.enabled = true
    enable_status.save
  end

  def self.disable(concept_edge)
    enable_status = concept_edge.concept_option
    if enable_status.nil?
      enable_status = Assessment::GuidanceConceptOption.new
      enable_status.concept_edge_id = concept_edge.id
    end

    enable_status.enabled = false
    enable_status.save
  end

  def self.is_enabled?(concept_edge)
    enable_status = concept_edge.guidance_concept_option
    result = false
    if !enable_status.nil?
      result = enable_status.enabled
    else
      result = false
    end

    result
  end

  
end
