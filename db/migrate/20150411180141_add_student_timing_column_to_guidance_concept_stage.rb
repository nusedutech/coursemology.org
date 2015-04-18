class AddStudentTimingColumnToGuidanceConceptStage < ActiveRecord::Migration
  def change
  	add_column :assessment_guidance_concept_stages, :seconds_to_complete, :integer, default: 0
  end
end
