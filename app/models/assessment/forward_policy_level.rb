class Assessment::ForwardPolicyLevel < ActiveRecord::Base
	acts_as_paranoid  

	attr_accessible :tag_id, :progression_threshold, :order, :wrong_threshold, :seconds_to_complete

	validates_presence_of :tag_id, :progression_threshold

	belongs_to :forward_policy, class_name: "Assessment::ForwardPolicy"
	belongs_to :tag, class_name: "Tag"
	has_many	:forward_groups, class_name: "Assessment::ForwardGroup"
end
