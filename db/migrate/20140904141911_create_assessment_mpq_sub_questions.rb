class CreateAssessmentMpqSubQuestions < ActiveRecord::Migration
  def change
    create_table :assessment_mpq_sub_questions do |t|
      t.integer :parent_id
      t.integer :child_id
      t.time :deleted_at

      t.timestamps
    end
  end
end
