class Assessment::GuidanceConceptCriteria < ActiveRecord::Base
  acts_as_paranoid
  acts_as_superclass as: :guidance_concept_criteria
  
  belongs_to :guidance_concept_option, class_name: Assessment::GuidanceConceptOption

end
