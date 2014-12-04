class AddMilestoneIdsToTutorialGroups < ActiveRecord::Migration
  def change
    add_column :tutorial_groups, :milestone_id, :integer

  end
end
