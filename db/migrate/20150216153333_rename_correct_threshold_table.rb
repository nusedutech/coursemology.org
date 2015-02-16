class RenameCorrectThresholdTable < ActiveRecord::Migration
  def change
    rename_table :assessment_guidance_concept_criteria_correct_thresholds, :assessment_correct_thresholds
  end
end
