class AddStudentTrackingColumnsToGuidanceConceptStage < ActiveRecord::Migration
  def change
  	add_column :assessment_guidance_concept_stages, :current_page_left_count, :integer, default: 0
  	add_column :assessment_guidance_concept_stages, :total_page_left_count, :integer, default: 0
  	add_column :assessment_guidance_concept_stages, :question_generate_at, :datetime, default: nil
  end
end
