class Assessment::WrongRatingThreshold < ActiveRecord::Base
  acts_as_paranoid
  is_a :concept_criterion, as: :guidance_concept_criterion, class_name: "Assessment::GuidanceConceptCriterion"

  attr_accessible :threshold, :absolute

  def is_type
    "wrong_rating_threshold"
  end

  #Return true if threshold not exceeded
  def evaluate right_amt, wrong_amt
    result = self.get_current right_amt, wrong_amt

    self.threshold.to_i > result
  end

  def get_current right_amt, wrong_amt
    if self.absolute
      result = wrong_amt.to_i - right_amt.to_i
    else
      result = wrong_amt.to_i
    end

    result
  end
end
