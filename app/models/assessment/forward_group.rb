class Assessment::ForwardGroup < ActiveRecord::Base
  acts_as_paranoid
	is_a :progression_group, as: :as_progression_group, class_name: "Assessment::ProgressionGroup"

	attr_accessible :submission_id, :uncompleted_questions, :completed_answers, :is_completed, :dued_at
	attr_accessible :correct_amount_left, :wrong_amount_left

	belongs_to :forward_policy_level, class_name: "Assessment::ForwardPolicyLevel"
end
