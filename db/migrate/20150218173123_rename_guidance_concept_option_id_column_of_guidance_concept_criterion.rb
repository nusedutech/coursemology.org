class RenameGuidanceConceptOptionIdColumnOfGuidanceConceptCriterion < ActiveRecord::Migration
  def change
    rename_column :assessment_guidance_concept_criteria, :assessment_guidance_concept_options_id, :guidance_concept_option_id
  end
end
