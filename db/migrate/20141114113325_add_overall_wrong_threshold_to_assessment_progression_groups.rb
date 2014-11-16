class AddOverallWrongThresholdToAssessmentProgressionGroups < ActiveRecord::Migration
  def change
		add_column :assessment_progression_groups, :wrong_qn_left, :integer, default: -1
  end
end
