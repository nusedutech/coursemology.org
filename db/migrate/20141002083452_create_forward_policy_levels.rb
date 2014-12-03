class CreateForwardPolicyLevels < ActiveRecord::Migration
  def up
		create_table :assessment_forward_policy_levels do |t|
      t.integer			:order, default: 0
			t.integer			:progression_threshold, default: -1
			t.integer			:wrong_threshold, default: -1
			t.integer			:seconds_to_complete, default: -1
			t.references	:tag

      t.datetime    :deleted_at
      t.timestamps
    end
  end

  def down
		drop_table :assessment_forward_policy_levels
  end
end
