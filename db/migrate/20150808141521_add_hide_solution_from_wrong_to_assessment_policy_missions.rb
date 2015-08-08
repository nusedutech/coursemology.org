class AddHideSolutionFromWrongToAssessmentPolicyMissions < ActiveRecord::Migration
  def change
    add_column :assessment_policy_missions, :hide_solution_from_wrong, :boolean, :default => false
  end
end
