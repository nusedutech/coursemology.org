class RenameTagOfForwardPolicyLevels < ActiveRecord::Migration
  def change
		rename_column :assessment_forward_policy_levels, :tag_id, :forward_policy_theme_id
    rename_column :assessment_forward_policy_levels, :tag_type, :forward_policy_theme_type
	end
end
