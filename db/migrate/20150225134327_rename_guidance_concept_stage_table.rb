class RenameGuidanceConceptStageTable < ActiveRecord::Migration
  def change
    rename_table :assessment_guidance_concept_stage, :assessment_guidance_concept_stages
  end
end
