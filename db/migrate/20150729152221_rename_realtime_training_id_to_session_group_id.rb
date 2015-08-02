class RenameRealtimeTrainingIdToSessionGroupId < ActiveRecord::Migration
  def change
    rename_column :assessment_realtime_sessions, :realtime_training_id, :session_group_id
  end
end
