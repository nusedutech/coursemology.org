class AddStudentTrackingColumnsToMcqAnswersRevision < ActiveRecord::Migration
  def change
  	remove_column :assessment_mcq_answers, :current_page_left_count
    remove_column :assessment_mcq_answers, :total_page_left_count
  	add_column :assessment_mcq_answers, :page_left_count, :integer, default: 0
  	add_column :assessment_mcq_answers, :seconds_to_complete, :integer, default: 0
  end
end
