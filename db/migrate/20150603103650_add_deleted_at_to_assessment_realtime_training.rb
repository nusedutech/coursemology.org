class AddDeletedAtToAssessmentRealtimeTraining < ActiveRecord::Migration
  def change
    add_column :assessment_realtime_trainings, :deleted_at, :datetime
  end
end
