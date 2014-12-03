class CreateForwardPolicies < ActiveRecord::Migration
  def up
		create_table :assessment_forward_policies do |t|
			t.integer		:overall_wrong_threshold, default: -1			

			t.datetime  :deleted_at
     	t.timestamps
		end
  end

  def down
		drop_table 	:assessment_forward_policies
  end
end
