class CreateAssessmentRealtimeTrainings < ActiveRecord::Migration
  def change
    create_table :assessment_realtime_trainings do |t|
      t.boolean :seat_randomizable
      t.boolean :average_grading

      t.timestamps
    end
  end
end
