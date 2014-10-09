class Assessment::ForwardPolicy < ActiveRecord::Base
  acts_as_paranoid
	is_a :progression_policy, as: :as_progression_policy, class_name: "Assessment::ProgressionPolicy"
	
	attr_accessible: :policy_mission_id, :overall_seconds_to_complete, :overall_wrong_threshold

	has_many	:forward_policy_levels, class_name: "Assessment::ForwardPolicyLevel", dependent: :destroy
end
