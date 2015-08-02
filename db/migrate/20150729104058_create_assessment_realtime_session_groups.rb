class CreateAssessmentRealtimeSessionGroups < ActiveRecord::Migration
  def change
    create_table :assessment_realtime_session_groups do |t|
      t.string :title
      t.integer :course_id
      t.integer :training_id
      t.integer :mission_id
      t.boolean :seat_randomizable
      t.boolean :average_grading

      t.timestamps
    end
  end
end
