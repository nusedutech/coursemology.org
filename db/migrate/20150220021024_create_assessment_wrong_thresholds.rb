class CreateAssessmentWrongThresholds < ActiveRecord::Migration
  def up
    create_table :assessment_wrong_thresholds do |t|
      t.integer :threshold

      t.datetime  :deleted_at
      t.timestamps
    end
  end

  def down
		drop_table  :assessment_wrong_thresholds
  end
end
