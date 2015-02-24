class AddDurationToAssessmentTraining < ActiveRecord::Migration
  def change
    add_column :assessment_trainings, :duration, :integer
  end
end
