class Assessment::GuidanceConceptCriterion < ActiveRecord::Base
  acts_as_paranoid
  acts_as_superclass as: :guidance_concept_criterion
  
  validates_presence_of :guidance_concept_option_id


  belongs_to :guidance_concept_option, class_name: Assessment::GuidanceConceptOption, foreign_key: "guidance_concept_option_id"

  scope :wrong_threshold_subcriteria, -> { where(guidance_concept_criterion_type: "Assessment::WrongThreshold") }
  scope :wrong_rating_threshold_subcriteria, -> { where(guidance_concept_criterion_type: "Assessment::WrongRatingThreshold") }
  scope :wrong_percent_threshold_subcriteria, -> { where(guidance_concept_criterion_type: "Assessment::WrongPercentThreshold") }

  def self.delete_with_new(criterion)
    if criterion.id.nil?
      criterion = nil
    else
      criterion.destroy
    end
  end

  def is_type
    nil
  end
end
