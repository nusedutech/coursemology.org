class CreateProgressionGroups < ActiveRecord::Migration
  def up
		create_table  :assessment_progression_groups do |t|
			#For MTI
			t.integer :as_progression_group_id
      t.string  :as_progression_group_type			

			t.references  :submission, index: true      

			t.string  :uncompleted_questions
		  t.string  :completed_answers
			t.boolean :is_completed, default: false

			t.datetime	:dued_at
      t.datetime  :deleted_at
      t.timestamps
    end
  end

  def down
		drop_table  :assessment_progression_groups
  end
end
