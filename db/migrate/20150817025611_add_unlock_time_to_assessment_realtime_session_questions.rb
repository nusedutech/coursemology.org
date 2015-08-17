class AddUnlockTimeToAssessmentRealtimeSessionQuestions < ActiveRecord::Migration
  def change
    add_column :assessment_realtime_session_questions, :unlock_time, :datetime
  end
end
