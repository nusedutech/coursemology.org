class AddGroupIdToTutorialGroup < ActiveRecord::Migration
  def change
    add_column :tutorial_groups, :group_id, :string
  end
end
