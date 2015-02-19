class Assessment::GuidanceConceptEdgeCriterion < ActiveRecord::Base
  acts_as_paranoid
  acts_as_superclass as: :guidance_concept_edge_criterion
  
  belongs_to :guidance_concept_edge_option, class_name: Assessment::GuidanceConceptEdgeOption, foreign_key: "guidance_concept_edge_option_id"

  scope :correct_threshold_subcriteria, -> { where(guidance_concept_edge_criterion_type: "Assessment::CorrectThreshold") }

  def self.delete_with_new(criterion)
    if criterion.id.nil?
      criterion = nil
    else
      criterion.destroy
    end
  end
end
