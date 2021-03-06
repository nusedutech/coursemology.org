class Assessment::WrongThreshold < ActiveRecord::Base
  acts_as_paranoid
  is_a :concept_criterion, as: :guidance_concept_criterion, class_name: "Assessment::GuidanceConceptCriterion"

  attr_accessible :threshold

  def is_type
    "wrong_threshold"
  end

  #Return true if threshold not exceeded
  def evaluate wrong_amt
    self.threshold.to_i > wrong_amt.to_i
  end
end
