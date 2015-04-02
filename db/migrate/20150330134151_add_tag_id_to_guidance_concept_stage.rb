class AddTagIdToGuidanceConceptStage < ActiveRecord::Migration
  def change
  	add_column :assessment_guidance_concept_stages, :tag_id, :integer, default: nil, index: true
  end
end
