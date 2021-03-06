class Assessment::GuidanceConceptEdgeOption < ActiveRecord::Base
  acts_as_paranoid
  acts_as_duplicable
  attr_accessible :enabled, :concept_edge_id
  validates_presence_of :concept_edge_id

  belongs_to :concept_edge, class_name: ConceptEdge, foreign_key: "concept_edge_id"

  has_many  :concept_edge_criteria, class_name: Assessment::GuidanceConceptEdgeCriterion, dependent: :destroy

  amoeba do
    include_field [:concept_edge_criteria]
  end

  def self.enable(concept_edge)
    enable_status = concept_edge.concept_edge_option
    if enable_status.nil?
      enable_status = Assessment::GuidanceConceptEdgeOption.new
      enable_status.concept_edge_id = concept_edge.id
    end

    enable_status.enabled = true
    enable_status.save
  end

  def self.disable(concept_edge)
    enable_status = concept_edge.concept_edge_option
    if enable_status.nil?
      enable_status = Assessment::GuidanceConceptEdgeOption.new
      enable_status.concept_edge_id = concept_edge.id
    end

    enable_status.enabled = false
    enable_status.save
  end

  def self.is_enabled?(concept_edge)
    enable_status = concept_edge.concept_edge_option
    result = false
    if !enable_status.nil?
      result = enable_status.enabled
    else
      result = false
    end

    result
  end

  def self.is_not_enabled?(concept_edge)
    enable_status = concept_edge.concept_edge_option
    result = true
    if enable_status.nil?
      result = true
    else
      result = !enable_status.enabled
    end

    result
  end

  def self.has_criteria?(concept_edge)
    enable_status = concept_edge.concept_edge_option
    result = false

    if !enable_status.nil?
      result = enable_status.concept_edge_criteria.size > 0
    else
      result = false
    end

    result
  end

end
