class RenameGuidanceConceptEdgeStageTable < ActiveRecord::Migration
  def change
    rename_table :assessment_guidance_concept_edge_stage, :assessment_guidance_concept_edge_stages
  end
end
