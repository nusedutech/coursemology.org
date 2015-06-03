class AddOptionGradingToAssessmentTrainings < ActiveRecord::Migration
  def change
    add_column :assessment_trainings, :option_grading, :boolean
  end
end
