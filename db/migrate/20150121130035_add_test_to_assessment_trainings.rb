class AddTestToAssessmentTrainings < ActiveRecord::Migration
  def change
    add_column :assessment_trainings, :test, :boolean, default: false
  end
end
