class RemoveMcqoptionToAssessmentMcqAnswers < ActiveRecord::Migration
  def change
		remove_column :assessment_mcq_answers, :mcq_option_id
	end
end
