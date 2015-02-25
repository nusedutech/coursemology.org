class AmendColumnOfGuidanceConceptCriteriaTable < ActiveRecord::Migration
  def change
    rename_column :assessment_guidance_concept_criteria, :guidance_concept_criteria_id, :guidance_concept_criterion_id
     rename_column :assessment_guidance_concept_criteria, :guidance_concept_criteria_type, :guidance_concept_criterion_type
    rename_column :assessment_guidance_concept_criteria, :assessment_guidance_concept_option_id, :guidance_concept_option_id
  end
end
