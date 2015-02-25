class AddCustomSettingsColumnToGuidanceQuizzes < ActiveRecord::Migration
  def change
    add_column :assessment_guidance_quizzes, :passing_edge_lock, :boolean, default: false
    add_column :assessment_guidance_quizzes, :neighbour_entry_lock, :boolean, default: false
  end
end
