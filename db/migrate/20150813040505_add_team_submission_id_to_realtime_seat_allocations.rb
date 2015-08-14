class AddTeamSubmissionIdToRealtimeSeatAllocations < ActiveRecord::Migration
  def change
    add_column :assessment_realtime_seat_allocations, :team_submission_id, :integer
  end
end
