class RenameRealtimeTrainingSessionToRealtimeSession < ActiveRecord::Migration
  def change
    rename_table :assessment_realtime_training_sessions, :assessment_realtime_sessions
  end
end
