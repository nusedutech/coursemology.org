class AddStudentFeedbackColumnsToGuidanceQuiz < ActiveRecord::Migration
  def change
  	add_column :assessment_guidance_quizzes, :feedback_show_scoreboard, :boolean, default: true
  	add_column :assessment_guidance_quizzes, :feedback_best_unattempted_weight, :integer, default: 1
  	add_column :assessment_guidance_quizzes, :feedback_notbest_unattempted_weight, :integer, default: 1
  end
end
