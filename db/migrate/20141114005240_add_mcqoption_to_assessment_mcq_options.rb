class AddMcqoptionToAssessmentMcqOptions < ActiveRecord::Migration
  def change
		add_column :assessment_mcq_options, :mcq_option_id, :integer
  end
end
