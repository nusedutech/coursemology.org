class Assessment::CorrectThreshold < ActiveRecord::Base
  acts_as_paranoid
  is_a :concept_edge_criterion, as: :guidance_concept_edge_criterion, class_name: "Assessment::GuidanceConceptEdgeCriterion"

  attr_accessible :threshold 

  def is_type
    "correct_threshold"
  end

  #Return true if threshold is reached
  def evaluate right_amt
    self.threshold.to_i <= right_amt.to_i
  end
end
