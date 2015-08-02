class RemoveTitleInAssessmentRealtimeSessionGroup < ActiveRecord::Migration
  def change
    remove_column :assessment_realtime_session_groups, :title
  end
end
