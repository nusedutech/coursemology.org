class AddMilestoneIdsToTutorialGroups < ActiveRecord::Migration
  def change
    add_column :tutorial_groups, :from_milestone_id, :integer
    add_column :tutorial_groups, :to_milestone_id, :integer
  end
end
