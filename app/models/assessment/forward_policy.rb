class Assessment::ForwardPolicy < ActiveRecord::Base
  acts_as_paranoid
	is_a :progression_policy, as: :as_progression_policy, class_name: "Assessment::ProgressionPolicy"
	
	attr_accessible :policy_mission_id, :overall_seconds_to_complete, :overall_wrong_threshold

	has_many	:forward_policy_levels, class_name: "Assessment::ForwardPolicyLevel", dependent: :destroy, foreign_key: :forward_policy_id

  amoeba do
    include_field [:forward_policy_levels]
  end

	def getSortedPolicyLevels
		self.forward_policy_levels.order("assessment_forward_policy_levels.order")
	end

	def deleteAllPolicyLevels
		self.forward_policy_levels.destroy_all
	end

	#Get the next forward policy level in order
	#If at last, return nil
	def nextPolicyLevel(currentPolicyLevel) 
		allOtherLevels = self.forward_policy_levels.where("assessment_forward_policy_levels.order > ?", currentPolicyLevel.order).order("assessment_forward_policy_levels.order")
		if allOtherLevels.size > 0
			return allOtherLevels[0]
		else
			return nil
		end
	end


  def getHighestLevelReached
  end
end
