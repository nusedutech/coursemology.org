class AddTestToAssessmentTrainings < ActiveRecord::Migration
  def change
    add_column :assessment_trainings, :test, :boolean
  end
end
