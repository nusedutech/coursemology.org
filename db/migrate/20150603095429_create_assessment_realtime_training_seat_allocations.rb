class CreateAssessmentRealtimeTrainingSeatAllocations < ActiveRecord::Migration
  def change
    create_table :assessment_realtime_training_seat_allocations do |t|
      t.integer :std_course_id
      t.integer :session_id
      t.string :seat_number

      t.timestamps
    end
  end
end
