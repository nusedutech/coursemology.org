class RenameGuidanceConceptOptionsTableToGuidanceConceptEdgeOptionsTable < ActiveRecord::Migration
  def change
    rename_table :assessment_guidance_concept_options, :assessment_guidance_concept_edge_options
  end
end
