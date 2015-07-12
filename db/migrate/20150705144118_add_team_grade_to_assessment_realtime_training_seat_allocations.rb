class AddTeamGradeToAssessmentRealtimeTrainingSeatAllocations < ActiveRecord::Migration
  def change
    add_column :assessment_realtime_training_seat_allocations, :team_grade, :float
  end
end
