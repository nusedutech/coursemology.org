class AmendForwardPolicyLevels < ActiveRecord::Migration
  def change
		add_column :assessment_forward_policy_levels, :forward_policy_id, :integer
		add_index :assessment_forward_policy_levels, :forward_policy_id
	end
end
