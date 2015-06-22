class CreateAssessmentRealtimeTrainingSessionQuestions < ActiveRecord::Migration
  def change
    create_table :assessment_realtime_training_session_questions do |t|
      t.integer :session_id
      t.integer :question_assessment_id
      t.boolean :unlock
      t.integer :unlock_count

      t.timestamps
    end
  end
end
