class CreateAssessmentGuidanceQuizzes < ActiveRecord::Migration
  def up
    create_table :assessment_guidance_quizzes do |t|
      t.datetime  :deleted_at
      t.timestamps
    end
  end

  def down
		drop_table  :assessment_guidance_quizzes
  end
end
