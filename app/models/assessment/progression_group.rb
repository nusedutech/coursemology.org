class Assessment::ProgressionGroup < ActiveRecord::Base
  acts_as_paranoid
	acts_as_superclass as: :as_progression_group

	attr_accessible :submission_id, :uncompleted_questions, :completed_answers, :is_completed, :dued_at

	belongs_to :submission, class_name: "Assessment::Submission"

	def isForwardGroup?
	  self.as_progression_group_type == "Assessment::ForwardGroup"
	end

	def getForwardGroup
	  return Assessment::ForwardGroup.find(self.as_progression_group_id)		
	end

	#Method to obtain tag name from related classes directly
	def getTagName
	  forwardGroup = self.getForwardGroup
	  forwardPolicyLevel = forwardGroup.getCorrespondingLevel
	  tag = forwardPolicyLevel.getTag

	  tag.name
	end
end
