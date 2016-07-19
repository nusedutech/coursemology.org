class AddColumnsToAssessmentRealtimeSessionGroups < ActiveRecord::Migration
  def change
    add_column :assessment_realtime_session_groups, :recitation, :boolean, default: false, after: :average_grading
  end
end
