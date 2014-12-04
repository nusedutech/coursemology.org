class AddCourseIdToAssessmentQuestions < ActiveRecord::Migration
  def change
    add_column :assessment_questions, :course_id, :integer
  end
end
