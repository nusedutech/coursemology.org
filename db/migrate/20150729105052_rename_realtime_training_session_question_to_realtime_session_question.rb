class RenameRealtimeTrainingSessionQuestionToRealtimeSessionQuestion < ActiveRecord::Migration
  def change
    rename_table :assessment_realtime_training_session_questions, :assessment_realtime_session_questions
  end
end
