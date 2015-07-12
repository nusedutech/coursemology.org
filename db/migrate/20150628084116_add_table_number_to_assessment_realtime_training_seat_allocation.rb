class AddTableNumberToAssessmentRealtimeTrainingSeatAllocation < ActiveRecord::Migration
  def change
    add_column :assessment_realtime_training_seat_allocations, :table_number, :integer
    change_column :assessment_realtime_training_seat_allocations, :seat_number, :integer
  end
end
