class CreateForwardGroups < ActiveRecord::Migration
  def up
		create_table  :assessment_forward_groups do |t|
			t.references  :forward_policy_level, index: true      

			t.integer		:correct_amount_left, default: -1
			t.integer		:wrong_amount_left, default: -1

      t.datetime  :deleted_at
      t.timestamps
    end
  end

  def down
		drop_table  :assessment_forward_groups
  end
end
