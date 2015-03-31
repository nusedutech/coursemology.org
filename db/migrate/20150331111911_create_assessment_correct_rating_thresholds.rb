class CreateAssessmentCorrectRatingThresholds < ActiveRecord::Migration
  def up
  	create_table :assessment_correct_rating_thresholds do |t|
      t.integer :threshold
      t.boolean :absolute, default: false

      t.datetime  :deleted_at
      t.timestamps
    end
  end

  def down
  	drop_table  :assessment_correct_rating_thresholds
  end
end
