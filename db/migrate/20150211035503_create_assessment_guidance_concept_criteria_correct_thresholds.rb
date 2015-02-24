class CreateAssessmentGuidanceConceptCriteriaCorrectThresholds < ActiveRecord::Migration
  def up
    create_table :assessment_guidance_concept_criteria_correct_thresholds do |t|
      t.integer :threshold

      t.datetime  :deleted_at
      t.timestamps
    end
  end

  def down
		drop_table  :assessment_guidance_concept_criteria_correct_thresholds
  end
end
