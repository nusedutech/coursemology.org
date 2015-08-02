class RemoveCourseIdInAssessmentRealtimeSessionGroup < ActiveRecord::Migration
  def change
    remove_column :assessment_realtime_session_groups, :course_id
  end
end
