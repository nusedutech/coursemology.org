class RenameRealtimeTrainingSeatAllocationToRealtimeSeatAllocation < ActiveRecord::Migration
  rename_table :assessment_realtime_training_seat_allocations, :assessment_realtime_seat_allocations
end
