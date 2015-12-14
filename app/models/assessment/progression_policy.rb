class Assessment::ProgressionPolicy < ActiveRecord::Base
  acts_as_paranoid
  acts_as_duplicable
	acts_as_superclass as: :as_progression_policy

	attr_accessible :policy_mission_id, :overall_seconds_to_complete

	belongs_to :policy_mission

	def isForwardPolicy?
		self.as_progression_policy_type == "Assessment::ForwardPolicy"
	end

	def getForwardPolicy
		return Assessment::ForwardPolicy.find(self.as_progression_policy_id)		
  end

  def dup
    s = self.specific
    d = s.amoeba_dup
    pp = super
    d.progression_policy = pp
    pp.as_progression_policy = d
    pp
  end
end
