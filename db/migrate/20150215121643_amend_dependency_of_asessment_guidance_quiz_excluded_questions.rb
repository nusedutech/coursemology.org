class AmendDependencyOfAsessmentGuidanceQuizExcludedQuestions < ActiveRecord::Migration
  def up
    drop_table  :assessment_guidance_quiz_excluded_question

    create_table :assessment_guidance_quiz_excluded_questions do |t|
      t.references  :assessment_question, index: true
      #For MTI
			t.boolean  :excluded

      t.datetime  :deleted_at
      t.timestamps
    end
  end

  def down
		drop_table  :assessment_guidance_quiz_excluded_questions
  end
end
