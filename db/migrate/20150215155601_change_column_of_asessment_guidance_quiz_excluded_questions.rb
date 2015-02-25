class ChangeColumnOfAsessmentGuidanceQuizExcludedQuestions < ActiveRecord::Migration
  def change
    add_column :assessment_guidance_quiz_excluded_questions, :question_id, :integer, index: true
    remove_column :assessment_guidance_quiz_excluded_questions, :assessment_question_id
  end
end
