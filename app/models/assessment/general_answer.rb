class Assessment::GeneralAnswer < ActiveRecord::Base
  acts_as_paranoid
  is_a :answer, as: :as_answer, class_name: "Assessment::Answer"

  has_one  :voted_answer, class_name: Assessment::GeneralAnswer, foreign_key: :voted_answer_id
  has_many  :answer_voters, class_name: Assessment::GeneralAnswer, foreign_key: :voted_answer_id
end


