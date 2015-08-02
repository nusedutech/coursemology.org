class AddDeletedAtToAssessmentRealtimeSessionGroup < ActiveRecord::Migration
  def change
    add_column :assessment_realtime_session_groups, :deleted_at, :datetime
  end
end
