class AmendMcqoptionToAssessmentMcqOptions < ActiveRecord::Migration
  def change
		remove_column :assessment_mcq_options, :mcq_option_id
		add_column :assessment_mcq_answers, :mcq_option_id, :integer
	end
end
