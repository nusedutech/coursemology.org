class CreateAssessmentRealtimeTrainingSessions < ActiveRecord::Migration
  def change
    create_table :assessment_realtime_training_sessions do |t|
      t.integer :student_group_id
      t.integer :realtime_training_id
      t.integer :number_of_table
      t.integer :seat_per_table
      t.datetime :start_time
      t.datetime :end_time
      t.boolean :status

      t.timestamps
    end
  end
end
