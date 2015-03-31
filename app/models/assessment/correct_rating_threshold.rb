class Assessment::CorrectRatingThreshold < ActiveRecord::Base
  acts_as_paranoid
  is_a :concept_edge_criterion, as: :guidance_concept_edge_criterion, class_name: "Assessment::GuidanceConceptEdgeCriterion"

  attr_accessible :threshold 

  def is_type
    "correct_rating_threshold"
  end

  #Return true if threshold is reached
  def evaluate right_amt, wrong_amt
    result = self.get_current right_amt, wrong_amt

    self.threshold.to_i <= result
  end

  def get_current right_amt, wrong_amt
    if self.absolute
      result = right_amt.to_i - wrong_amt.to_i
    else
      result = right_amt.to_i
    end

    result
  end
end
