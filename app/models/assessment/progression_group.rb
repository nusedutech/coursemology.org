class Assessment::ProgressionGroup < ActiveRecord::Base
  acts_as_paranoid
	acts_as_superclass as: :as_progression_group

	attr_accessible :submission_id, :uncompleted_questions, :completed_answers, :is_completed, :dued_at

	belongs_to: :submission, class_name: "Assessment::Submission"
end
