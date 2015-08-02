class AddDeletedAtToAssessmentRealtimeSession < ActiveRecord::Migration
  def change
    add_column :assessment_realtime_sessions, :deleted_at, :datetime
  end
end
