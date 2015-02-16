class Assessment::CorrectThreshold < ActiveRecord::Base
  acts_as_paranoid
  is_a :concept_criterion, as: :guidance_concept_criterion, class_name: "Assessment::GuidanceConceptCriterion"

  attr_accessible :threshold 
end
