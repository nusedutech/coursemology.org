class Assessment::GuidanceConceptCriteria::CorrectThreshold < ActiveRecord::Base
  acts_as_paranoid
  is_a :guidance_concept_criteria, as: :guidance_concept_criteria, class_name: Assessment::GuidanceConceptCriteria
end
