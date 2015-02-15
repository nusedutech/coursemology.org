class AmendDependencyOfGuidanceConceptCriteria < ActiveRecord::Migration
  def up
    drop_table  :assessment_guidance_concept_criteria

    create_table :assessment_guidance_concept_criterias do |t|
      t.references  :assessment_guidance_concept_option, index: true
      #For MTI
			t.integer :guidance_concept_criteria_id
      t.string  :guidance_concept_criteria_type	

      t.datetime  :deleted_at
      t.timestamps
    end
  end

  def down
		drop_table  :assessment_guidance_concept_criterias
  end
end
