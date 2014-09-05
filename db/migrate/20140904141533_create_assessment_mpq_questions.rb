class CreateAssessmentMpqQuestions < ActiveRecord::Migration
  def change
    create_table :assessment_mpq_questions do |t|
      t.time :deleted_at

      t.timestamps
    end
  end
end
