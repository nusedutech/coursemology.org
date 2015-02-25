class CreateGuidanceConceptStage < ActiveRecord::Migration
  def up
    create_table :assessment_guidance_concept_stage do |t|
      t.references  :assessment_submission, index: true
      t.integer  :topicconcept_id, index: true
            

      t.integer :total_right, default: 0
      t.integer :total_wrong, default: 0
      
      t.string  :uncompleted_questions
      t.string  :completed_answers
      
      t.integer  :disabled_topicconcept_id, index: true
      t.datetime  :disabled_at
            

      t.datetime  :deleted_at
      t.timestamps
    end
  end

  def down
    drop_table  :assessment_guidance_concept_stage
  end
end
