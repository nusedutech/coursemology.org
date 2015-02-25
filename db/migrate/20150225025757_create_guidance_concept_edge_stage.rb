class CreateGuidanceConceptEdgeStage < ActiveRecord::Migration
  def up
    create_table :assessment_guidance_concept_edge_stage do |t|
      t.references :assessment_guidance_concept_stage, index: true
      t.references :concept_edge, index: true

      t.integer :total_right, default: 0
      t.integer :total_wrong, default: 0

      t.boolean :passed, default: false

      t.datetime  :deleted_at
      t.timestamps
    end
  end

  def down
    drop_table :assessment_guidance_concept_edge_stage
  end
end
