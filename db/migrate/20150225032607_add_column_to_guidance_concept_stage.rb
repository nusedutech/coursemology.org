class AddColumnToGuidanceConceptStage < ActiveRecord::Migration
  def change
    add_column :assessment_guidance_concept_stage, :failed, :boolean, default: false
  end
end
