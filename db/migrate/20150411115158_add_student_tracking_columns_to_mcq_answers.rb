class AddStudentTrackingColumnsToMcqAnswers < ActiveRecord::Migration
  def change
  	add_column :assessment_mcq_answers, :current_page_left_count, :integer, default: 0
  	add_column :assessment_mcq_answers, :total_page_left_count, :integer, default: 0
  end
end
