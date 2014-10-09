class Assessment::ProgressionPolicy < ActiveRecord::Base
  acts_as_paranoid
	acts_as_superclass as: :as_progression_policy

	attr_accessible: :policy_mission_id, :overall_seconds_to_complete

	belongs_to :policy_mission
end
