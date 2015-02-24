class RenameGuidanceConceptOptionIdOfAssessmentGuidanceConceptCriteriaToGuidanceConceptEdgeOptionId < ActiveRecord::Migration
  def change
    rename_column :assessment_guidance_concept_criteria, :guidance_concept_option_id, :guidance_concept_edge_option_id
  end
end
