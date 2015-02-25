class CreateAssessmentGuidanceQuizExcludedQuestions < ActiveRecord::Migration
  def up
    create_table :assessment_guidance_quiz_excluded_question do |t|
      t.references  :assessment_question, index: true
      #For MTI
			t.boolean  :excluded

      t.datetime  :deleted_at
      t.timestamps
    end
  end

  def down
		drop_table  :assessment_guidance_quiz_excluded_question
  end
end
