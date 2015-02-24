class AddIsEntryColumnToGuidanceConceptOption < ActiveRecord::Migration
  def change
    add_column :assessment_guidance_concept_options, :is_entry, :boolean, default: false
  end
end
