class AddShowSolutionAfterCloseAndAlwaysFullExpToAssessmentTraining < ActiveRecord::Migration
  def change
    add_column :assessment_trainings, :show_solution_after_close, :boolean, :default => false
    add_column :assessment_trainings, :always_full_exp, :boolean, :default => false
  end
end
