class Assessment::WrongPercentThreshold < ActiveRecord::Base
  acts_as_paranoid
  is_a :concept_criterion, as: :guidance_concept_criterion, class_name: "Assessment::GuidanceConceptCriterion"

  attr_accessible :threshold

  def is_type
    "wrong_percent_threshold"
  end

  #Return true if threshold not exceeded
  def evaluate right_amt, wrong_amt
    percent = self.get_current right_amt, wrong_amt

    self.threshold.to_f > percent
  end

  def get_current right_amt, wrong_amt
    total = right_amt.to_i + wrong_amt.to_i
    if total <= 0 
      percent = 0
    else
      percent = wrong_amt.to_f * 100 / total
    end

    percent
  end
end
