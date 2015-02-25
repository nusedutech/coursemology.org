class RenameGuidanceConceptCriterionTable < ActiveRecord::Migration
  def change
    rename_table :assessment_guidance_concept_criterias, :assessment_guidance_concept_criteria
  end
end
