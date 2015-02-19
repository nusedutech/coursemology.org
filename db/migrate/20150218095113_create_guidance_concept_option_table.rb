class CreateGuidanceConceptOptionTable < ActiveRecord::Migration
  def up
    create_table :assessment_guidance_concept_options do |t|
      t.references  :topicconcept, index: true
      t.boolean :enabled, default: false

      t.datetime  :deleted_at
      t.timestamps
    end
  end

  def down
    drop_table  :assessment_guidance_concept_options
  end
end
