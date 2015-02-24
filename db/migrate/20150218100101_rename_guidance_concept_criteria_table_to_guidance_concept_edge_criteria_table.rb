class RenameGuidanceConceptCriteriaTableToGuidanceConceptEdgeCriteriaTable < ActiveRecord::Migration
  def change
    rename_table :assessment_guidance_concept_criteria, :assessment_guidance_concept_edge_criteria
    rename_column :assessment_guidance_concept_edge_criteria, :guidance_concept_criterion_id, :guidance_concept_edge_criterion_id
    rename_column :assessment_guidance_concept_edge_criteria, :guidance_concept_criterion_type, :guidance_concept_edge_criterion_type
  end
end
