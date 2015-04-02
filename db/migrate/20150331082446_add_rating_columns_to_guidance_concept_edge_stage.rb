class AddRatingColumnsToGuidanceConceptEdgeStage < ActiveRecord::Migration
  def change
  	add_column :assessment_guidance_concept_edge_stages, :rating_right, :integer, default: 0
  	add_column :assessment_guidance_concept_edge_stages, :rating_wrong, :integer, default: 0
  end
end
