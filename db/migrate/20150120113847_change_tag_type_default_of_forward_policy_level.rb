class ChangeTagTypeDefaultOfForwardPolicyLevel < ActiveRecord::Migration
  def change
		change_column :assessment_forward_policy_levels, :tag_type, :string, default: nil
  end
end
