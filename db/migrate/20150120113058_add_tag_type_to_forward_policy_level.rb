class AddTagTypeToForwardPolicyLevel < ActiveRecord::Migration
  def change
		add_column :assessment_forward_policy_levels, :tag_type, :string, default: "Tag"
  end
end
