class AmendForwardPolicyLevelsForConsecutive < ActiveRecord::Migration
  def change
		add_column :assessment_forward_policy_levels, :is_consecutive, :boolean, default: false
		add_column :assessment_forward_groups, :is_consecutive, :boolean, default: false
	end
end
