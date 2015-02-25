class CreateAssessmentGuidanceConceptCriteria < ActiveRecord::Migration
  def up
    create_table :assessment_guidance_concept_criteria do |t|
      t.references  :assessment_guidance_concept_options, index: true
      #For MTI
      t.integer :guidance_concept_criteria_id
      t.string  :guidance_concept_criteria_type	

      t.datetime  :deleted_at
      t.timestamps
    end
  end

  def down
    drop_table  :assessment_guidance_concept_criteria
  end
end
